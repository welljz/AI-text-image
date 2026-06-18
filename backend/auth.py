"""认证模块 — Token 认证，单用户场景

auth.yaml 格式:
  username: admin
  password: <明文，首次启动自动哈希>
  token: <登录后生成>

工作流:
1. install.sh 写入 auth.yaml（明文密码）
2. 后端首次启动 → 检测明文 → werkzeug 哈希 → 覆盖文件
3. 登录 → 验证密码 → 生成 token → 存入 auth.yaml
4. 后续请求带 Authorization: Bearer <token>
5. 修改密码 → token 作废 → 需重新登录
"""

import logging
import secrets
from pathlib import Path
from functools import wraps

import yaml
from flask import request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

logger = logging.getLogger(__name__)

AUTH_FILE = Path(__file__).parent.parent / 'auth.yaml'


def _is_hashed(password: str) -> bool:
    """判断密码是否已哈希（werkzeug 哈希以 scrypt: 或 pbkdf2: 开头）"""
    return password.startswith('scrypt:') or password.startswith('pbkdf2:')


def load_auth() -> dict:
    """读取认证配置，明文密码自动哈希"""
    if not AUTH_FILE.exists():
        return {'username': 'admin', 'password': None, 'token': None}

    with open(AUTH_FILE, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f) or {}

    password = data.get('password', '')
    if password and not _is_hashed(password):
        logger.info("检测到明文密码，自动哈希...")
        data['password'] = generate_password_hash(password)
        save_auth(data)
        logger.info("密码哈希完成")

    return data


def save_auth(data: dict):
    """保存认证配置到 auth.yaml"""
    AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(AUTH_FILE, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)


def verify_password(password: str) -> bool:
    """验证密码"""
    auth = load_auth()
    stored = auth.get('password', '')
    if not stored:
        return False
    if _is_hashed(stored):
        return check_password_hash(stored, password)
    # 兼容未哈希的明文密码
    return stored == password


def generate_token() -> str:
    return secrets.token_hex(32)


def check_token(token: str) -> bool:
    """验证 token 是否有效"""
    if not token:
        return False
    auth = load_auth()
    stored_token = auth.get('token', '')
    return stored_token is not None and stored_token == token


def login_required(f):
    """装饰器：要求 Bearer token 认证"""

    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        token = auth_header.replace('Bearer ', '') if auth_header.startswith('Bearer ') else ''
        if not token or not check_token(token):
            return jsonify({'success': False, 'error': '未登录或登录已过期'}), 401
        return f(*args, **kwargs)

    return decorated
