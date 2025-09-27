"""
Interface for AICLOUD with flexible audio_url
"""

import base64
import hashlib
import hmac
import json
import uuid
from datetime import datetime
from time import mktime
from urllib.parse import urlparse
from wsgiref.handlers import format_date_time

import requests


class VoiceCloneClient:
    def __init__(self, app_id, api_key, api_secret):
        self.app_id = app_id
        self.api_key = api_key
        self.api_secret = api_secret
        self.requrl = "http://evo-dx.xf-yun.com/individuation/sgen/reg"

    @staticmethod
    def sha256base64(data):
        sha256 = hashlib.sha256()
        sha256.update(data)
        digest = base64.b64encode(sha256.digest()).decode(encoding="utf-8")
        return digest

    def assemble_auth_header(self, method="POST", body=""):
        u = urlparse(self.requrl)
        host = u.hostname
        path = u.path
        now = datetime.now()
        date = format_date_time(mktime(now.timetuple()))
        digest = "SHA256=" + self.sha256base64(body.encode())
        signature_origin = (
            f"host: {host}\ndate: {date}\n{method} {path} HTTP/1.1\ndigest: {digest}"
        )
        signature_sha = hmac.new(
            self.api_secret.encode("utf-8"),
            signature_origin.encode("utf-8"),
            digestmod=hashlib.sha256,
        ).digest()
        signature_sha = base64.b64encode(signature_sha).decode(encoding="utf-8")
        authorization = f'api_key="{self.api_key}", algorithm="hmac-sha256", \
        headers="host date request-line digest", signature="{signature_sha}"'
        headers = {
            "host": host,
            "date": date,
            "authorization": authorization,
            "digest": digest,
            "Content-Type": "application/json",
        }
        return headers

    @staticmethod
    def get_data(audio_url):
        try:
            response = requests.get(audio_url, timeout=30)
            response.raise_for_status()  # 这会抛出HTTPError如果请求失败
            audio_data = response.content
            base64_audio = base64.b64encode(audio_data).decode("utf-8")
            return base64_audio
        # except requests.RequestException as e:
        #     # 如果请求失败，返回一个错误信息
        #     return {"error": str(e)}
        except requests.exceptions.HTTPError as e:
            error_code = e.response.status_code
            error_message = str(e)
            # print(f"下载失败：{error_code},{error_message}")
            return (error_code, error_message)

    def train(self, res_id, audio_url):
        audio_data = self.get_data(audio_url)
        if isinstance(audio_data, tuple):
            # 如果下载音频时出错，直接返回错误信息
            return res_id, audio_data
        body = {
            "common": {"app_id": self.app_id},
            "business": {
                "res_id": res_id,
                "res_desc": {"res_type": "voice_clone", "from": "cn", "to": "cn"},
            },
            "data": self.get_data(audio_url),
        }

        bds = json.dumps(body)
        headers = self.assemble_auth_header(body=bds)
        resp = requests.post(self.requrl, headers=headers, data=bds, timeout=30)

        if resp.status_code != 200:
            raise Exception(
                f"Request failed with status code {resp.status_code}: {resp.text}"
            )

        return res_id, resp.json()


if __name__ == "__main__":
    client = VoiceCloneClient(
        app_id="a01c2bc7",
        api_key="5f93d1890c25748e68a514c62f79b8b1",
        api_secret="ODc3MDhkZjA4M2E4ZDgzODM0MmY4MzZk",
    )
    try:
        res_id, messages = client.train(
            res_id=str(uuid.uuid4()),
            audio_url="https://beijing2.cn-bj.ufileos.com/2024-11-04-11-34-01.mp3",
        )
        # print('res_id:', res_id)
        # print('messages:', messages, type(messages))
    except (requests.RequestException, ValueError, KeyError):
        # print('报错:',e)
        pass
