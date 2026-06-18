"""系统管理 API — 检查更新、一键更新、重启服务"""

import os
import subprocess
from pathlib import Path
from flask import Blueprint, jsonify

from backend.auth import login_required


PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
SERVICE_NAME = PROJECT_DIR.name
UPDATE_SCRIPT = f'/usr/local/bin/{SERVICE_NAME}-update'
UPDATE_LOG = f'/tmp/{SERVICE_NAME}-update.log'


def create_system_blueprint():
    system_bp = Blueprint('system', __name__)

    @system_bp.route('/system/check-update', methods=['GET'])
    @login_required
    def check_update():
        """检查是否有新版本"""
        try:
            # git fetch 拉取最新信息（只读，不修改本地文件）
            fetch = subprocess.run(
                ['git', 'fetch', 'origin', 'main'],
                cwd=str(PROJECT_DIR),
                capture_output=True, text=True, timeout=30
            )
            if fetch.returncode != 0:
                return jsonify({
                    'success': False,
                    'error': '无法连接 GitHub',
                    'detail': fetch.stderr.strip()[-200:]
                })

            # 当前 commit
            current = subprocess.run(
                ['git', 'rev-parse', 'HEAD'],
                cwd=str(PROJECT_DIR),
                capture_output=True, text=True
            ).stdout.strip()

            # 远端 commit
            latest = subprocess.run(
                ['git', 'rev-parse', 'origin/main'],
                cwd=str(PROJECT_DIR),
                capture_output=True, text=True
            ).stdout.strip()

            # 当前 commit 信息
            current_msg = subprocess.run(
                ['git', 'log', '-1', '--format=%s', current],
                cwd=str(PROJECT_DIR),
                capture_output=True, text=True
            ).stdout.strip()

            has_update = current != latest
            new_commits = []

            if has_update:
                log_result = subprocess.run(
                    ['git', 'log', '--oneline', f'{current}..{latest}'],
                    cwd=str(PROJECT_DIR),
                    capture_output=True, text=True
                )
                if log_result.stdout.strip():
                    new_commits = log_result.stdout.strip().split('\n')[:10]

            return jsonify({
                'success': True,
                'current_commit': current[:7],
                'current_message': current_msg,
                'latest_commit': latest[:7],
                'has_update': has_update,
                'new_commits': new_commits
            })
        except subprocess.TimeoutExpired:
            return jsonify({'success': False, 'error': '连接 GitHub 超时'})
        except Exception as e:
            return jsonify({'success': False, 'error': str(e)})

    @system_bp.route('/system/update', methods=['POST'])
    @login_required
    def do_update():
        """后台执行一键更新：git pull + uv sync + pnpm build"""
        if not os.path.exists(UPDATE_SCRIPT):
            return jsonify({
                'success': False,
                'error': f'更新脚本不存在: {UPDATE_SCRIPT}，请重新运行 install.sh'
            }), 400

        # 清空日志
        with open(UPDATE_LOG, 'w') as f:
            f.write('')

        # 后台执行更新脚本
        subprocess.Popen(
            ['bash', UPDATE_SCRIPT],
            stdout=open(UPDATE_LOG, 'a'),
            stderr=subprocess.STDOUT,
            start_new_session=True
        )

        return jsonify({
            'success': True,
            'message': '更新已开始，请等待构建完成后重启'
        })

    @system_bp.route('/system/update-status', methods=['GET'])
    @login_required
    def update_status():
        """查询更新进度（读取日志）"""
        log_text = ''
        done = False
        has_error = False

        if os.path.exists(UPDATE_LOG):
            with open(UPDATE_LOG, 'r') as f:
                log_text = f.read()
            done = '更新完成' in log_text
            has_error = '[✗]' in log_text

        return jsonify({
            'success': True,
            'log': log_text[-5000:],
            'done': done,
            'error': has_error
        })

    @system_bp.route('/system/restart', methods=['POST'])
    @login_required
    def restart_service():
        """重启系统服务（需要 sudoers 权限）"""
        try:
            subprocess.Popen(
                ['sudo', 'systemctl', 'restart', SERVICE_NAME],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            return jsonify({
                'success': True,
                'message': '服务正在重启，页面将在几秒后刷新...'
            })
        except Exception as e:
            return jsonify({'success': False, 'error': str(e)}), 500

    return system_bp
