"""Replicate 图片生成器"""
import logging
import time
import requests
from typing import Dict, Any, Optional, List
from .base import ImageGeneratorBase

logger = logging.getLogger(__name__)


class ReplicateGenerator(ImageGeneratorBase):
    """Replicate 生成器"""

    BASE_URL = "https://api.replicate.com/v1"
    POLL_INTERVAL = 2   # 轮询间隔（秒）
    MAX_WAIT = 300       # 最大等待时间（秒）

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        logger.debug("初始化 ReplicateGenerator...")
        self.model_version = config.get('model', 'openai/gpt-image-2')
        self.default_aspect_ratio = config.get('default_aspect_ratio', '3:4')
        # Replicate 像素尺寸映射
        default_size_map = {"1:1": "1024x1024", "3:4": "1024x1536", "4:3": "1536x1024", "16:9": "1536x864", "9:16": "864x1536"}
        self.size_map = config.get('size_map', default_size_map)
        self.quality = config.get('quality', 'standard')
        logger.info(f"ReplicateGenerator 初始化完成: model={self.model_version}")

    def validate_config(self) -> bool:
        if not self.api_key:
            raise ValueError("Replicate API Key 未配置")
        return True

    def get_supported_sizes(self) -> List[str]:
        return ["1:1", "2:3 (竖屏)", "3:2 (横屏)"]

    def get_supported_aspect_ratios(self) -> List[str]:
        return ["1:1", "2:3", "3:2"]

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
        self.validate_config()

        if aspect_ratio is None:
            aspect_ratio = self.default_aspect_ratio

        # Replicate gpt-image-2 用 aspect_ratio，不用 size
        # RedInk aspect_ratio → Replicate 格式：3:4→2:3, 4:3→3:2, 其他→映射或1:1
        aspect_map = {
            "1:1": "1:1", "3:4": "2:3", "4:3": "3:2",
            "9:16": "2:3", "16:9": "3:2", "2:3": "2:3", "3:2": "3:2"
        }
        repl_aspect = aspect_map.get(aspect_ratio, "1:1")

        logger.info(f"Replicate 生成图片: model={self.model_version}, aspect={repl_aspect}")

        # 构建 input
        input_data = {
            "prompt": prompt,
            "aspect_ratio": repl_aspect,
            "number_of_images": 1,
        }

        # 质量参数（gpt-image-2 支持）— 参数优先于配置
        final_quality = quality or self.quality
        if final_quality:
            input_data["quality"] = final_quality

        payload = {
            "version": self.model_version,
            "input": input_data,
        }

        headers = {
            "Authorization": f"Token {self.api_key}",
            "Content-Type": "application/json",
            "Prefer": "wait=60",  # 同步等待最多 60 秒
        }

        api_url = f"{self.BASE_URL}/predictions"
        logger.debug(f"  发送请求到: {api_url}")

        resp = requests.post(api_url, headers=headers, json=payload, timeout=360)

        if resp.status_code not in (200, 201, 202):
            error_detail = resp.text[:500]
            logger.error(f"Replicate 请求失败: status={resp.status_code}, error={error_detail}")
            raise Exception(
                f"Replicate API 请求失败 (状态码: {resp.status_code})\n"
                f"错误详情: {error_detail}"
            )

        result = resp.json()
        logger.debug(f"  Replicate 响应: status={result.get('status')}")

        # 如果已完成，直接取 output
        if result.get("status") == "succeeded":
            return self._fetch_output(result)

        # 否则轮询等待
        prediction_id = result.get("id")
        if not prediction_id:
            raise Exception(f"Replicate 响应缺少 prediction id: {str(result)[:200]}")

        logger.info(f"  等待 Replicate 完成: {prediction_id}")
        return self._poll_until_done(prediction_id)

    def _poll_until_done(self, prediction_id: str) -> bytes:
        """轮询直到预测完成"""
        headers = {"Authorization": f"Token {self.api_key}"}
        url = f"{self.BASE_URL}/predictions/{prediction_id}"
        elapsed = 0

        while elapsed < self.MAX_WAIT:
            time.sleep(self.POLL_INTERVAL)
            elapsed += self.POLL_INTERVAL

            resp = requests.get(url, headers=headers, timeout=30)
            if resp.status_code != 200:
                logger.warning(f"  轮询返回 {resp.status_code}，重试...")
                continue

            result = resp.json()
            status = result.get("status")
            logger.debug(f"  轮询: status={status}, elapsed={elapsed}s")

            if status == "succeeded":
                return self._fetch_output(result)
            elif status == "failed":
                error = result.get("error", "未知错误")
                raise Exception(f"Replicate 生成失败: {error}")
            elif status == "canceled":
                raise Exception("Replicate 任务被取消")

        raise Exception(f"Replicate 超时（等待 {self.MAX_WAIT} 秒）")

    def _fetch_output(self, result: dict) -> bytes:
        """从 prediction 结果中提取图片"""
        output = result.get("output")

        # output 可能是 URL 字符串 或 URL 数组
        if isinstance(output, str):
            return self._download_image(output)
        elif isinstance(output, list) and len(output) > 0:
            return self._download_image(output[0])

        raise Exception(
            f"无法从 Replicate 响应中提取图片: {str(result)[:300]}"
        )

    def _download_image(self, url: str) -> bytes:
        """下载图片"""
        logger.info(f"下载 Replicate 图片: {url[:100]}...")
        try:
            resp = requests.get(url, timeout=60)
            if resp.status_code == 200:
                logger.info(f"✅ Replicate 图片下载成功: {len(resp.content)} bytes")
                return resp.content
            raise Exception(f"下载图片失败: HTTP {resp.status_code}")
        except requests.exceptions.Timeout:
            raise Exception("下载图片超时")
        except Exception as e:
            raise Exception(f"下载图片失败: {str(e)}")
