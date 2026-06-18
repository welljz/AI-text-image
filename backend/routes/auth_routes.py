"""认证 API 路由"""

from flask import Blueprint, request, jsonify

from werkzeug.security import generate_password_hash, check_password_hash

from backend.auth import load_auth, save_auth, verify_credentials, generate_token, login_required, _is_hashed


def create_auth_blueprint():
    auth_bp = Blueprint('auth', __name__)

    @auth_bp.route('/auth/status', methods=['GET'])
    def auth_status():
        """检查是否需要初始化（是否有可用的登录凭据）"""
        data = load_auth()
        has_password = bool(data.get('password'))
        return jsonify({
            'success': True,
            'initialized': has_password
        })

    @auth_bp.route('/auth/login', methods=['POST'])
    def login():
        """登录 — 验证用户名+密码，返回 token"""
        body = request.get_json(silent=True) or {}
        username = body.get('username', '').strip()
        password = body.get('password', '')

        if not username or not password:
            return jsonify({'success': False, 'error': '请输入用户名和密码'}), 400

        if not verify_credentials(username, password):
            return jsonify({'success': False, 'error': '用户名或密码错误'}), 401

        auth = load_auth()
        token = generate_token()
        auth['token'] = token
        save_auth(auth)

        return jsonify({
            'success': True,
            'token': token,
            'username': auth.get('username', 'admin')
        })

    @auth_bp.route('/auth/change-account', methods=['POST'])
    @login_required
    def change_account():
        """修改账户 — 可同时修改用户名和密码；改密码需验证旧密码"""
        body = request.get_json(silent=True) or {}
        new_username = body.get('new_username', '').strip()
        old_password = body.get('old_password', '')
        new_password = body.get('new_password', '')

        if not new_username and not new_password:
            return jsonify({'success': False, 'error': '请提供要修改的用户名或新密码'}), 400

        auth = load_auth()

        # 修改密码：需验证旧密码
        if new_password:
            if len(new_password) < 6:
                return jsonify({'success': False, 'error': '新密码至少 6 位'}), 400
            if not old_password:
                return jsonify({'success': False, 'error': '修改密码需要输入旧密码'}), 400

            stored_pw = auth.get('password', '')
            ok = False
            if _is_hashed(stored_pw):
                ok = check_password_hash(stored_pw, old_password)
            else:
                ok = (stored_pw == old_password)
            if not ok:
                return jsonify({'success': False, 'error': '旧密码错误'}), 401

            auth['password'] = generate_password_hash(new_password)
            auth['token'] = None  # 改密码作废旧 token，需重新登录

        # 修改用户名：登录态下可直接改，不失效 token
        if new_username:
            if len(new_username) < 1 or len(new_username) > 32:
                return jsonify({'success': False, 'error': '用户名长度需在 1~32 位之间'}), 400
            auth['username'] = new_username

        save_auth(auth)

        msg_parts = []
        if new_username:
            msg_parts.append('用户名已更新')
        if new_password:
            msg_parts.append('密码已修改，请重新登录')

        return jsonify({
            'success': True,
            'message': '；'.join(msg_parts),
            'username': auth.get('username', 'admin'),
            'require_relogin': bool(new_password)
        })

    return auth_bp
