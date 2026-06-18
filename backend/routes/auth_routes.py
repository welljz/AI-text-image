"""认证 API 路由"""

from flask import Blueprint, request, jsonify

from backend.auth import load_auth, save_auth, verify_password, generate_token, login_required


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
        """登录 — 验证密码返回 token"""
        body = request.get_json(silent=True) or {}
        password = body.get('password', '')

        if not password:
            return jsonify({'success': False, 'error': '请输入密码'}), 400

        if not verify_password(password):
            return jsonify({'success': False, 'error': '密码错误'}), 401

        auth = load_auth()
        token = generate_token()
        auth['token'] = token
        save_auth(auth)

        return jsonify({
            'success': True,
            'token': token,
            'username': auth.get('username', 'admin')
        })

    @auth_bp.route('/auth/change-password', methods=['POST'])
    @login_required
    def change_password():
        """修改密码 — token 作废需重新登录"""
        body = request.get_json(silent=True) or {}
        old_password = body.get('old_password', '')
        new_password = body.get('new_password', '')

        if not old_password or not new_password:
            return jsonify({'success': False, 'error': '请填写旧密码和新密码'}), 400

        if len(new_password) < 6:
            return jsonify({'success': False, 'error': '新密码至少 6 位'}), 400

        if not verify_password(old_password):
            return jsonify({'success': False, 'error': '旧密码错误'}), 401

        from werkzeug.security import generate_password_hash

        auth = load_auth()
        auth['password'] = generate_password_hash(new_password)
        auth['token'] = None  # 作废旧 token，需重新登录
        save_auth(auth)

        return jsonify({
            'success': True,
            'message': '密码修改成功，请重新登录'
        })

    return auth_bp
