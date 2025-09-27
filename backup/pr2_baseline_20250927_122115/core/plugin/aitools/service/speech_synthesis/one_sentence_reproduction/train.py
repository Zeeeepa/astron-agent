import hashlib
import json
import logging
import time

import requests


class VoiceTrainer:
    def __init__(self, app_id, api_key, audio_url):
        self.app_id = app_id
        self.api_key = api_key
        self.audio_url = audio_url
        self.token = self._get_token()
        self.task_id = ""
        self.text_id = 5001  # 通用的训练文本集ID
        self.text_seg_id = 1  # 文本段ID，这里以1为例
        self.create_task_message = []  # 收集创建任务失败的信息

    def _get_authorization(self, data):
        timestamp = int(time.time() * 1000)
        body = json.dumps(data)
        key_sign = hashlib.md5(
            (self.api_key + str(timestamp)).encode("utf-8")
        ).hexdigest()
        sign = hashlib.md5((key_sign + body).encode("utf-8")).hexdigest()
        return sign

    def _get_token(self):
        timestamp = int(time.time() * 1000)
        body = {
            "base": {
                "appid": self.app_id,
                "version": "v1",
                "timestamp": str(timestamp),
            },
            "model": "remote",
        }
        headers = {
            "Authorization": self._get_authorization(body),
            "Content-Type": "application/json",
        }
        response = requests.post(
            "http://avatar-hci.xfyousheng.com/aiauth/v1/token",
            data=json.dumps(body),
            headers=headers,
            timeout=30,
        )
        resp = response.json()
        if resp["retcode"] == "000000":
            return resp["accesstoken"]
        else:
            raise Exception(f"Failed to get token: {resp}")

    def _get_sign(self, body):
        timestamp = int(time.time() * 1000)
        key_sign = hashlib.md5(str(body).encode("utf-8")).hexdigest()
        sign = hashlib.md5(
            (self.api_key + str(timestamp) + key_sign).encode("utf-8")
        ).hexdigest()
        return sign

    def _get_header(self, sign):
        return {
            "X-Sign": sign,
            "X-Token": self.token,
            "X-AppId": self.app_id,
            "X-Time": str(int(time.time() * 1000)),
        }

    def get_training_text(self):
        body = {"textId": self.text_id}
        sign = self._get_sign(body)
        headers = self._get_header(sign)
        response = requests.post(
            "http://opentrain.xfyousheng.com/voice_train/task/traintext",
            json=body,
            headers=headers,
            timeout=30,
        ).json()
        return response["data"]["textSegs"]

    def create_task(self):
        body = {
            "taskName": "test23",  # 任务名称，可自定义
            "sex": 1,  # 训练音色性别   1：男     2 ：女
            "resourceType": 12,
            "resourceName": "创建音库test1",  # 音库名称，可自定义
        }
        sign = self._get_sign(body)
        headers = self._get_header(sign)
        response = requests.post(
            "http://opentrain.xfyousheng.com/voice_train/task/add",
            json=body,
            headers=headers,
            timeout=30,
        ).json()
        # print("创建任务：", response)
        logging.info("创建任务:%s", response)
        code = response["code"]
        if code != 0:
            self.create_task_message.append(response)
        self.task_id = response["data"]
        return self.task_id

    def add_audio(self):
        if not self.task_id:
            self.create_task()
        body = {
            "taskId": self.task_id,
            "audioUrl": self.audio_url,
            "textId": self.text_id,
            "textSegId": self.text_seg_id,
        }
        sign = self._get_sign(body)
        headers = self._get_header(sign)
        response = requests.post(
            "http://opentrain.xfyousheng.com/voice_train/audio/v1/add",
            json=body,
            headers=headers,
            timeout=30,
        ).json()
        return response

    def submit_task(self):
        body = {"taskId": self.task_id}
        sign = self._get_sign(body)
        headers = self._get_header(sign)
        response = requests.post(
            "http://opentrain.xfyousheng.com/voice_train/task/submit",
            json=body,
            headers=headers,
            timeout=30,
        ).json()
        return response

    def get_process(self):
        body = {"taskId": self.task_id}
        sign = self._get_sign(body)
        headers = self._get_header(sign)
        response = requests.post(
            "http://opentrain.xfyousheng.com/voice_train/task/result",
            json=body,
            headers=headers,
            timeout=30,
        ).json()
        return response

    def train(self):
        # 获取训练文本
        texts = self.get_training_text()
        # print("Training texts:", texts)
        logging.info("Training texts:%s", texts)

        # 创建训练任务
        task_id = self.create_task()
        # print("Created task with ID:", task_id)
        logging.info("Created task with ID:%s", task_id)

        # 添加音频到训练任务
        add_audio_response = self.add_audio()
        # print("Added audio to task:", add_audio_response)
        logging.info("Added audio to task:%s", add_audio_response)

        # 提交训练任务
        submit_response = self.submit_task()
        # print("Submitted task:", submit_response)
        logging.info("Submitted task:%s", submit_response)

        # 获取训练过程
        res_id = ""
        while True:
            process = self.get_process()
            try:
                status = process["data"]["trainStatus"]
                if status == -1:
                    # print("Training in progress...")
                    time.sleep(5)  # 等待一段时间再检查状态
                elif status == 1:
                    res_id = process["data"]["assetId"]
                    # print("Training successful, res_id:", res_id)
                    break
                else:
                    # print("Training failed:", process)
                    break
            except KeyError:
                # print("训练失败:", e)
                break

        return res_id, self.create_task_message


if __name__ == "__main__":
    test_app_id = "8cadd878"
    test_app_key = "113deac0254287560c918cc9ac9fbcf7"
    # app_id = 'f7c57afa'
    # app_key = '80faf25fa998240971010bb4be32a236'
    test_audio_url = (
        "https://beijing2.cn-bj.ufileos.com/%E5%90%88%E8%82%A5%E8%AF%9D.wav"
    )

    trainer, message = VoiceTrainer(test_app_id, test_app_key, test_audio_url).train()
    # print('音色id:', trainer)
    # print('训练失败的报错:', message)
