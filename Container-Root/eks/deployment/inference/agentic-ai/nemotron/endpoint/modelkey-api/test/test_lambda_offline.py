#!/usr/bin/env python3
"""Offline self-test of lambda/model_key/lambda_function.py with a stubbed boto3 - no AWS call, no network.

Proves: 200 with endpoint/model/api_key on a readable secret and the key in NO log line; 404 unavailable when the
secret is missing, scheduled for deletion or has no api_key; 502 error on another AWS failure or a malformed secret;
no crash on an event without requestContext. Run: python3 test/test_lambda_offline.py  (exit 0 = all checks pass).
"""
import importlib.util
import io
import json
import logging
import os
import pathlib
import sys
import types

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "lambda" / "model_key" / "lambda_function.py"
KEY = "testkey0123456789abcdefghijklmnopqrstuvwxyz0123"
ARN = "arn:aws:secretsmanager:us-west-2:123456789012:secret:nemotron/modelkey-AbCdEf"
EVENT = {"httpMethod": "POST", "path": "/modelkey", "requestContext": {"identity": {
    "userArn": "arn:aws:sts::111122223333:assumed-role/WSParticipantRole/attendee", "accountId": "111122223333",
    "vpceId": "vpce-0123456789abcdef0", "sourceIp": "10.0.0.5"}}}


class FakeError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.response = {"Error": {"Code": code, "Message": code}}


class FakeClient:
    def __init__(self, behaviour):
        self.behaviour, self.calls = behaviour, []

    def get_secret_value(self, SecretId):
        self.calls.append(SecretId)
        if isinstance(self.behaviour, Exception):
            raise self.behaviour
        if isinstance(self.behaviour, str):
            return {"SecretString": self.behaviour}
        return {"SecretString": json.dumps(self.behaviour)}


state = {"client": None}
fake_boto3 = types.ModuleType("boto3")
fake_boto3.client = lambda name: state["client"]
sys.modules["boto3"] = fake_boto3
os.environ["SECRET_ARN"] = ARN
spec = importlib.util.spec_from_file_location("lambda_function", SRC)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

checks = []


def check(name, ok):
    checks.append(ok)
    print(("PASS  " if ok else "FAIL  ") + name)


def run(behaviour, event=EVENT):
    state["client"] = FakeClient(behaviour)
    mod._client = None
    buf = io.StringIO()
    h = logging.StreamHandler(buf)
    root = logging.getLogger()
    root.addHandler(h)
    try:
        resp = mod.handler(event, None)
    finally:
        root.removeHandler(h)
    return resp, buf.getvalue()


good = {"endpoint": "https://nemotron.example.com/v1", "model": "nvidia/model", "api_key": KEY}
resp, logs = run(good)
check("200 on a readable secret", resp["statusCode"] == 200)
check("body carries endpoint, model and api_key", json.loads(resp["body"]) == good)
check("the key appears in no log line", logs.strip() != "" and KEY not in logs)
check("the log names the caller account and the outcome", "111122223333" in logs and "issued" in logs)
check("Cache-Control no-store on the answer", resp["headers"]["Cache-Control"] == "no-store")
check("the secret is read by SECRET_ARN exactly once", state["client"].calls == [ARN])

resp, logs = run(FakeError("ResourceNotFoundException"))
check("404 unavailable when the secret is missing", resp["statusCode"] == 404 and json.loads(resp["body"]) == {"status": "unavailable"})
check("no key in the 404 body or logs", KEY not in resp["body"] and KEY not in logs)

resp, logs = run(FakeError("InvalidRequestException"))
check("404 unavailable when the secret is scheduled for deletion", resp["statusCode"] == 404)

resp, logs = run(FakeError("InternalServiceError"))
check("502 error on another AWS failure", resp["statusCode"] == 502 and json.loads(resp["body"]) == {"status": "error"})
check("the 502 log names the error code", "InternalServiceError" in logs)

resp, logs = run({"endpoint": "e", "model": "m"})
check("404 unavailable when the secret has no api_key", resp["statusCode"] == 404)

resp, logs = run("{not json")
check("502 error on a malformed secret string", resp["statusCode"] == 502)

resp, logs = run(good, event={})
check("200 on an event without requestContext (no crash)", resp["statusCode"] == 200 and json.loads(resp["body"])["api_key"] == KEY)

n_ok = sum(1 for c in checks if c)
print(f"VERDICT {'PASS' if n_ok == len(checks) else 'FAIL'} {n_ok}/{len(checks)}")
sys.exit(0 if n_ok == len(checks) else 1)
