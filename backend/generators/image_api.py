"""Image API 图片生成器"""
import logging
import base64
import requests
from typing import Dict, Any, Optional, List, Union
from .base import ImageGeneratorBase
from ..utils.image_compressor import compress_image

logger = logging.getLogger(__name__)


class ImageApiGenerator(ImageGeneratorBase):
    """Image API 生成器"""

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        logger.debug("初始化 ImageApiGenerator...")
        self.base_url = config.get('base_url', 'https://api.example.com').rstrip('/')
        if self.base_url.endswith('/v1'):
            self.base_url = self.base_url[:-3]
        self.model = config.get('model', 'default-model')
        self.default_aspect_ratio = config.get('default_aspect_ratio', '3:4')
        self.image_size = config.get('image_size', '4K')

        # 尺寸映射：优先使用 provider 配置的 size_map，否则用默认
        default_size_map = {"1:1": "1024x1024", "3:4": "768x1024", "4:3": "1024x768", "16:9": "1280x720", "9:16": "720x1280"}
        self.size_map = config.get('size_map', default_size_map)

        # 质量参数（gpt-image-2 等模型支持 low/medium/high）
        self.quality = config.get('quality')
        # 水印：默认不发送（由 API 决定），配置后可显式设置
        self.watermark = config.get('watermark')
        # 是否支持参考图（image 参数），默认关闭避免 Unknown parameter 错误
        self.support_reference_image = config.get('support_reference_image', False)

        # 支持自定义端点路径
        endpoint_type = config.get('endpoint_type', '/v1/images/generations')
        # 兼容旧的简写格式
        if endpoint_type == 'images':
            endpoint_type = '/v1/images/generations'
        elif endpoint_type == 'chat':
            endpoint_type = '/v1/chat/completions'
        # 确保以 / 开头
        if not endpoint_type.startswith('/'):
            endpoint_type = '/' + endpoint_type
        self.endpoint_type = endpoint_type

        logger.info(f"ImageApiGenerator 初始化完成: base_url={self.base_url}, model={self.model}, endpoint={self.endpoint_type}")

    def validate_config(self) -> bool:
        """验证配置是否有效"""
        if not self.api_key:
            logger.error("Image API Key 未配置")
            raise ValueError(
                "Image API Key 未配置。\n"
                "解决方案：在系统设置页面编辑该服务商，填写 API Key"
            )
        return True

    def get_supported_sizes(self) -> List[str]:
        """获取支持的图片尺寸"""
        return ["1K", "2K", "4K"]

    def get_supported_aspect_ratios(self) -> List[str]:
        """获取支持的宽高比"""
        return ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9"]

    def generate_image(
        self,
        prompt: str,
        aspect_ratio: str = None,
        temperature: float = 1.0,
        model: str = None,
        quality: str = None,
        reference_image: Optional[bytes] = None,
        reference_images: Optional[List[bytes]] = None,
        **kwargs
    ) -> bytes:
        """
        生成图片

        Args:
            prompt: 图片描述
            aspect_ratio: 宽高比
            temperature: 创意度（未使用，保留接口兼容）
            model: 模型名称
            quality: 图片质量（覆盖配置默认值）
            reference_image: 单张参考图片数据（向后兼容）
            reference_images: 多张参考图片数据列表

        Returns:
            生成的图片二进制数据
        """
        self.validate_config()

        if aspect_ratio is None:
            aspect_ratio = self.default_aspect_ratio

        if model is None:
            model = self.model

        # 调用时参数优先于配置
        current_quality = quality or self.quality

        logger.info(f"Image API 生成图片: model={model}, aspect_ratio={aspect_ratio}, quality={current_quality}, endpoint={self.endpoint_type}")

        # 根据端点类型选择不同的生成方式
        if 'chat' in self.endpoint_type or 'completions' in self.endpoint_type:
            return self._generate_via_chat_api(prompt, aspect_ratio, model, reference_image, reference_images, current_quality)
        else:
            return self._generate_via_images_api(prompt, aspect_ratio, model, reference_image, reference_images, current_quality)

    def _generate_via_images_api(
        self,
        prompt: str,
        aspect_ratio: str,
        model: str,
        reference_image: Optional[bytes] = None,
        reference_images: Optional[List[bytes]] = None,
        quality: str = None
    ) -> bytes:
        """通过 /v1/images/generations 端点生成图片"""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        # aspect_ratio 转 size 像素值（优先使用 provider 配置的映射）
        img_size = self.size_map.get(aspect_ratio, "768x1024")
        payload = {
            "model": model,
            "prompt": prompt,
            "size": img_size,
            "n": 1
        }

        # 水印：配置了才发送
        if self.watermark is not None:
            payload["watermark"] = self.watermark

        # 质量参数：配置了才发送
        if quality:
            payload["quality"] = quality

        # 收集所有参考图片
        all_reference_images = []
        if reference_images and len(reference_images) > 0:
            all_reference_images.extend(reference_images)
        if reference_image and reference_image not in all_reference_images:
            all_reference_images.append(reference_image)

        # 如果有参考图片，根据 provider 配置决定是否传 image 参数
        if all_reference_images:
            logger.debug(f"  添加 {len(all_reference_images)} 张参考图片")

            # 压缩第一张参考图
            compressed_img = compress_image(all_reference_images[0], max_size_kb=200)
            base64_image = base64.b64encode(compressed_img).decode('utf-8')
            data_uri = f"data:image/png;base64,{base64_image}"

            ref_count = len(all_reference_images)
            # prompt 已包含页面专属 visual_prompt，参考风格仅为辅助约束
            enhanced_prompt = f"""{prompt}

<风格连贯性约束>
与参考图（共{ref_count}张）保持一致：色调、光影质感、画面氛围。勿改变上述内容的主体构图和元素。
</风格连贯性约束>"""

            if self.support_reference_image:
                # 支持参考图的 API：传 image + 风格约束 prompt（模型能看到参考图）
                payload["image"] = data_uri
                payload["prompt"] = enhanced_prompt
                logger.debug(f"  image 参数已设置 (support_reference_image=True)")
            else:
                # 不支持参考图的 API：直接用原始 prompt，不加无效的风格约束
                logger.debug(f"  跳过 image 参数 (support_reference_image=False)，使用原始 prompt")

        api_url = f"{self.base_url}{self.endpoint_type}"
        logger.debug(f"  发送请求到: {api_url}")
        response = requests.post(api_url, headers=headers, json=payload, timeout=300)

        if response.status_code != 200:
            error_detail = response.text[:500]
            logger.error(f"Image API 请求失败: status={response.status_code}, error={error_detail}")
            raise Exception(
                f"Image API 请求失败 (状态码: {response.status_code})\n"
                f"错误详情: {error_detail}\n"
                f"请求地址: {api_url}\n"
                "可能原因：\n"
                "1. API密钥无效或已过期\n"
                "2. 请求参数不符合API要求\n"
                "3. API服务端错误\n"
                "4. Base URL配置错误\n"
                "建议：检查API密钥和base_url配置"
            )

        result = response.json()
        logger.debug(f"  API 响应: data 长度={len(result.get('data', []))}")

        if "data" in result and len(result["data"]) > 0:
            item = result["data"][0]

            # b64_json 可能为 null，用 get 安全取值
            b64 = item.get("b64_json")
            if b64:
                if b64.startswith("data:"):
                    b64 = b64.split(",", 1)[1]
                image_data = base64.b64decode(b64)
                logger.info(f"✅ Image API 图片生成成功 (b64): {len(image_data)} bytes")
                return image_data

            # url 可能为 null
            url = item.get("url")
            if url:
                logger.info(f"下载生成的图片: {url[:80]}...")
                resp = requests.get(url, timeout=60)
                if resp.status_code == 200:
                    logger.info(f"✅ Image API 图片下载成功: {len(resp.content)} bytes")
                    return resp.content
                raise Exception(f"下载图片失败: HTTP {resp.status_code}")

        # Fallback: 尝试 Chat Completions 格式（云雾AI 等返回 choices[0].message.content）
        logger.debug("  data 字段为空，尝试 Chat Completions 格式...")
        image_data = self._extract_image_from_chat_response(result)
        if image_data:
            logger.info(f"✅ Image API 图片生成成功 (chat fallback): {len(image_data)} bytes")
            return image_data

        logger.error(f"无法从响应中提取图片数据: {str(result)[:200]}")
        raise Exception(
            f"图片数据提取失败：未找到 data.b64_json 或 choices[0].message.content。\n"
            f"API响应片段: {str(result)[:500]}\n"
            "可能原因：\n"
            "1. API返回格式与预期不符\n"
            "2. response_format 参数未生效\n"
            "3. 该模型不支持 b64_json 格式\n"
            "建议：检查API文档确认返回格式要求"
        )

    def _generate_via_chat_api(
        self,
        prompt: str,
        aspect_ratio: str,
        model: str,
        reference_image: Optional[bytes] = None,
        reference_images: Optional[List[bytes]] = None,
        quality: str = None
    ) -> bytes:
        """通过 /v1/chat/completions 端点生成图片（如即梦 API）"""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        # 构建用户消息内容
        user_content: Any = prompt

        # 收集所有参考图片
        all_reference_images = []
        if reference_images and len(reference_images) > 0:
            all_reference_images.extend(reference_images)
        if reference_image and reference_image not in all_reference_images:
            all_reference_images.append(reference_image)

        # 如果有参考图片，构建多模态消息
        if all_reference_images:
            logger.debug(f"  添加 {len(all_reference_images)} 张参考图片到 chat 消息")
            content_parts = [{"type": "text", "text": prompt}]

            for idx, img_data in enumerate(all_reference_images):
                compressed_img = compress_image(img_data, max_size_kb=200)
                logger.debug(f"  参考图 {idx}: {len(img_data)} -> {len(compressed_img)} bytes")
                base64_image = base64.b64encode(compressed_img).decode('utf-8')
                content_parts.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:image/png;base64,{base64_image}"}
                })

            user_content = content_parts

        payload = {
            "model": model,
            "messages": [{"role": "user", "content": user_content}],
            "max_tokens": 4096,
            "temperature": 1.0
        }

        api_url = f"{self.base_url}{self.endpoint_type}"
        logger.info(f"Chat API 生成图片: {api_url}, model={model}")

        response = requests.post(api_url, headers=headers, json=payload, timeout=300)

        if response.status_code != 200:
            error_detail = response.text[:500]
            status_code = response.status_code

            if status_code == 401:
                raise Exception(
                    "❌ API Key 认证失败\n\n"
                    "【可能原因】\n"
                    "1. API Key 无效或已过期\n"
                    "2. API Key 格式错误\n\n"
                    "【解决方案】\n"
                    "在系统设置页面检查 API Key 是否正确"
                )
            elif status_code == 429:
                raise Exception(
                    "⏳ API 配额或速率限制\n\n"
                    "【解决方案】\n"
                    "1. 稍后再试\n"
                    "2. 检查 API 配额使用情况"
                )
            else:
                raise Exception(
                    f"❌ Chat API 请求失败 (状态码: {status_code})\n\n"
                    f"【错误详情】\n{error_detail[:300]}\n\n"
                    f"【请求地址】{api_url}\n"
                    f"【模型】{model}"
                )

        result = response.json()
        logger.debug(f"Chat API 响应: {str(result)[:500]}")

        # 解析 Chat Completions 格式响应
        image_data = self._extract_image_from_chat_response(result)
        if image_data:
            return image_data

        raise Exception(
            "❌ 无法从 Chat API 响应中提取图片数据\n\n"
            f"【响应内容】\n{str(result)[:500]}\n\n"
            "【可能原因】\n"
            "1. 该模型不支持图片生成\n"
            "2. 响应格式与预期不符\n"
            "3. 提示词被安全过滤\n\n"
            "【解决方案】\n"
            "1. 确认模型名称正确\n"
            "2. 修改提示词后重试"
        )

    def _extract_image_from_chat_response(self, result: dict) -> Optional[bytes]:
        """
        从 Chat Completions 格式的响应中提取图片数据

        支持以下格式:
        1. Markdown 图片链接: ![xxx](url)
        2. Markdown Base64: ![xxx](data:image/...)
        3. 纯 Base64 data URL
        4. 纯 URL

        Returns:
            图片二进制数据，如果无法提取则返回 None
        """
        import re

        if "choices" not in result or len(result["choices"]) == 0:
            return None

        choice = result["choices"][0]
        if "message" not in choice or "content" not in choice["message"]:
            return None

        content = choice["message"]["content"]

        if not isinstance(content, str):
            return None

        # Markdown 图片链接: ![xxx](url)
        pattern = r'!\[.*?\]\((https?://[^\s\)]+)\)'
        urls = re.findall(pattern, content)
        if urls:
            logger.info(f"从 Markdown 提取到 {len(urls)} 张图片，下载第一张...")
            return self._download_image(urls[0])

        # Markdown 图片 Base64: ![xxx](data:image/...)
        base64_pattern = r'!\[.*?\]\((data:image\/[^;]+;base64,[^\s\)]+)\)'
        base64_urls = re.findall(base64_pattern, content)
        if base64_urls:
            logger.info("从 Markdown 提取到 Base64 图片数据")
            base64_data = base64_urls[0].split(",")[1]
            return base64.b64decode(base64_data)

        # 纯 Base64 data URL
        if content.startswith("data:image"):
            logger.info("检测到 Base64 图片数据")
            base64_data = content.split(",")[1]
            return base64.b64decode(base64_data)

        # 纯 URL
        if content.startswith("http://") or content.startswith("https://"):
            logger.info("检测到图片 URL")
            return self._download_image(content.strip())

        # 尝试将整个 content 作为 base64 解码（有些 API 直接返回 base64）
        try:
            image_data = base64.b64decode(content)
            if len(image_data) > 100:  # 至少要有意义的图片数据
                logger.info(f"✅ 从纯文本提取 Base64 图片数据: {len(image_data)} bytes")
                return image_data
        except Exception:
            pass

        return None

    def _download_image(self, url: str) -> bytes:
        """下载图片并返回二进制数据"""
        logger.info(f"下载图片: {url[:100]}...")
        try:
            response = requests.get(url, timeout=60)
            if response.status_code == 200:
                logger.info(f"✅ 图片下载成功: {len(response.content)} bytes")
                return response.content
            else:
                raise Exception(f"下载图片失败: HTTP {response.status_code}")
        except requests.exceptions.Timeout:
            raise Exception("❌ 下载图片超时，请重试")
        except Exception as e:
            raise Exception(f"❌ 下载图片失败: {str(e)}")
