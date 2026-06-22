"""
域名绑定 API 路由

功能：
- GET /api/domain: 获取当前域名配置
- POST /api/domain: 更新域名配置
"""

import logging
from pathlib import Path
import yaml
from flask import Blueprint, request, jsonify

logger = logging.getLogger(__name__)

CONFIG_DIR = Path(__file__).parent.parent.parent
APP_SETTINGS_PATH = CONFIG_DIR / 'app_settings.yaml'


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

            # 清除 Config 缓存，使 CORS 生效
            from backend.config import Config
            Config.reload_domain_config()

            logger.info(f"域名已更新: {domain or '(未设置)'}")

            return jsonify({
                'success': True,
                'message': '域名已保存',
                'domain': domain
            })

        except Exception as e:
            logger.error(f"保存域名配置失败: {e}")
            return jsonify({
                'success': False,
                'error': f'保存域名配置失败: {str(e)}'
            }), 500

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
