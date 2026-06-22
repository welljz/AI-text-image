"""
域名绑定 API 路由

功能：
- GET /api/domain: 获取当前域名配置
- POST /api/domain: 更新域名配置
"""

import logging
import subprocess
from pathlib import Path
import yaml
from flask import Blueprint, request, jsonify

logger = logging.getLogger(__name__)

CONFIG_DIR = Path(__file__).parent.parent.parent
APP_SETTINGS_PATH = CONFIG_DIR / 'app_settings.yaml'
SERVICE_SLUG = CONFIG_DIR.name
NGINX_HELPER = f'/usr/local/bin/{SERVICE_SLUG}-nginx'


def create_domain_blueprint():
    """创建域名配置路由蓝图（工厂函数，支持多次调用）"""
    domain_bp = Blueprint('domain', __name__)

    @domain_bp.route('/domain', methods=['GET'])
    def get_domain():
        """获取当前域名配置"""
        try:
            config = _read_app_settings()
            return jsonify({
                'success': True,
                'domain': config.get('domain', '')
            })
        except Exception as e:
            logger.error(f"获取域名配置失败: {e}")
            return jsonify({
                'success': False,
                'error': f'获取域名配置失败: {str(e)}'
            }), 500

    @domain_bp.route('/domain', methods=['POST'])
    def set_domain():
        """更新域名配置"""
        try:
            data = request.get_json()
            if data is None:
                return jsonify({
                    'success': False,
                    'error': '请求数据格式错误'
                }), 400

            domain = data.get('domain', '').strip()

            config = _read_app_settings()
            config['domain'] = domain
            _write_app_settings(config)

            # 清除 Config 缓存并同步 CORS，使域名即时生效无需重启
            from backend.config import Config
            Config.reload_domain_config()
            Config.sync_cors_origins()

            # 更新 Nginx 配置（80 端口域名 server block）
            nginx_msg = ''
            if Path(NGINX_HELPER).exists():
                try:
                    if domain:
                        result = subprocess.run(
                            ['sudo', NGINX_HELPER, 'set', domain],
                            capture_output=True, text=True, timeout=30
                        )
                    else:
                        result = subprocess.run(
                            ['sudo', NGINX_HELPER, 'clear'],
                            capture_output=True, text=True, timeout=30
                        )
                    if result.returncode == 0:
                        nginx_msg = '，Nginx 已更新'
                        logger.info(f"Nginx 域名配置已更新: {result.stdout.strip()}")
                    else:
                        nginx_msg = '，但 Nginx 更新失败（请检查服务器配置）'
                        logger.warning(f"Nginx 更新失败: {result.stderr.strip()}")
                except Exception as e:
                    nginx_msg = '，Nginx 配置未更新（helper 执行异常）'
                    logger.warning(f"调用 Nginx helper 失败: {e}")

            logger.info(f"域名已更新: {domain or '(未设置)'}")

            return jsonify({
                'success': True,
                'message': f'域名已保存{nginx_msg}',
                'domain': domain
            })

        except Exception as e:
            logger.error(f"保存域名配置失败: {e}")
            return jsonify({
                'success': False,
                'error': f'保存域名配置失败: {str(e)}'
            }), 500

    @domain_bp.route('/domain/cert', methods=['POST'])
    def apply_cert():
        """申请 SSL 证书（Let's Encrypt）"""
        try:
            data = request.get_json()
            if data is None:
                return jsonify({'success': False, 'error': '请求数据格式错误'}), 400

            email = data.get('email', '').strip()
            domain = _read_app_settings().get('domain', '').strip()

            if not domain:
                return jsonify({'success': False, 'error': '请先设置域名'}), 400
            if not email:
                return jsonify({'success': False, 'error': '请输入邮箱'}), 400

            if not Path(NGINX_HELPER).exists():
                return jsonify({
                    'success': False,
                    'error': f'Nginx helper 不存在，请重新运行 install.sh'
                }), 400

            result = subprocess.run(
                ['sudo', NGINX_HELPER, 'cert', domain, email],
                capture_output=True, text=True, timeout=120
            )

            if result.returncode == 0:
                logger.info(f"SSL 证书申请成功: {domain}")
                return jsonify({
                    'success': True,
                    'message': f'SSL 证书已生效: https://{domain}'
                })
            else:
                logger.warning(f"SSL 证书申请失败: {result.stdout.strip()} {result.stderr.strip()}")
                return jsonify({
                    'success': False,
                    'error': '证书申请失败，请确认域名 DNS 已正确解析到本服务器'
                }), 500

        except subprocess.TimeoutExpired:
            return jsonify({'success': False, 'error': '证书申请超时，请重试'}), 500
        except Exception as e:
            logger.error(f"SSL 证书申请异常: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    return domain_bp


def _read_app_settings() -> dict:
    """读取 app_settings.yaml，不存在时返回默认值"""
    if APP_SETTINGS_PATH.exists():
        with open(APP_SETTINGS_PATH, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {'domain': ''}
    return {'domain': ''}


def _write_app_settings(config: dict):
    """写入 app_settings.yaml"""
    with open(APP_SETTINGS_PATH, 'w', encoding='utf-8') as f:
        yaml.dump(config, f, allow_unicode=True, default_flow_style=False)
