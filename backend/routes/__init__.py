"""
API 路由模块

本模块将 API 路由按功能拆分为多个子模块：
- outline_routes: 大纲生成相关 API
- image_routes: 图片生成/获取相关 API
- history_routes: 历史记录 CRUD API
- config_routes: 配置管理 API
- content_routes: 内容生成相关 API（标题、文案、标签）
- auth_routes: 登录认证 API

所有路由都注册到统一的 /api 前缀下
"""

from flask import Blueprint, request, jsonify


# 无需认证的公开路由
PUBLIC_PATHS = {
    '/api/auth/login',
    '/api/auth/status',
    '/api/health',
    '/api/config/settings',  # 前端读取公开设置
}


def _is_public_path(path: str) -> bool:
    """判断路径是否为公开接口（无需认证）"""
    # 图片资源公开访问
    if path.startswith('/api/images/'):
        return True
    # 精确匹配
    if path in PUBLIC_PATHS:
        return True
    return False


def create_api_blueprint():
    """
    创建并配置主 API 蓝图

    每次调用都会创建新的蓝图实例，支持多次 create_app() 调用（如测试环境）

    Returns:
        配置好的 api Blueprint
    """
    from .outline_routes import create_outline_blueprint
    from .image_routes import create_image_blueprint
    from .history_routes import create_history_blueprint
    from .config_routes import create_config_blueprint
    from .content_routes import create_content_blueprint
    from .auth_routes import create_auth_blueprint
    from .system_routes import create_system_blueprint

    # 创建主 API 蓝图
    api_bp = Blueprint('api', __name__, url_prefix='/api')

    # 将子蓝图注册到主蓝图（不带额外前缀）
    api_bp.register_blueprint(create_outline_blueprint())
    api_bp.register_blueprint(create_image_blueprint())
    api_bp.register_blueprint(create_history_blueprint())
    api_bp.register_blueprint(create_config_blueprint())
    api_bp.register_blueprint(create_content_blueprint())
    api_bp.register_blueprint(create_auth_blueprint())
    api_bp.register_blueprint(create_system_blueprint())

    # 全局 Token 校验（公开接口放行）
    @api_bp.before_request
    def check_auth():
        if _is_public_path(request.path):
            return None
        # 允许 OPTIONS 预检请求通过（CORS）
        if request.method == 'OPTIONS':
            return None

        from backend.auth import check_token

        auth_header = request.headers.get('Authorization', '')
        token = auth_header.replace('Bearer ', '') if auth_header.startswith('Bearer ') else ''

        if not token or not check_token(token):
            return jsonify({'success': False, 'error': '未登录或登录已过期'}), 401
        return None

    return api_bp


def register_routes(app):
    """
    注册所有 API 路由到 Flask 应用

    Args:
        app: Flask 应用实例
    """
    api_bp = create_api_blueprint()
    app.register_blueprint(api_bp)


__all__ = ['register_routes', 'create_api_blueprint']
