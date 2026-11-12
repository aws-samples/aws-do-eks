"""POST /modelkey: hands the current model key to IAM-authenticated callers of the private REST API.

The key lives in ONE Secrets Manager secret, a JSON document {"endpoint": ..., "model": ..., "api_key": ...} that the
CloudFormation template generates; this function reads it and returns it. It never logs the key: each log line carries
the caller identity and the outcome only. Answers: 200 {"endpoint", "model", "api_key"}; 404 {"status": "unavailable"}
when the secret is missing, scheduled for deletion or has no api_key (the event is over or the endpoint is down);
502 {"status": "error"} on any other failure. The deployed copy is the ZipFile of ../../template.yaml (index.handler);
test/check_template.py proves the two are identical and test/test_lambda_offline.py exercises this file with a stubbed
boto3.
"""
import json
import logging
import os

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)
SECRET_ARN = os.environ.get("SECRET_ARN", "")
_client = None


def _secrets():
    global _client
    if _client is None:
        _client = boto3.client("secretsmanager")
    return _client


def _error_code(exc):
    return ((getattr(exc, "response", None) or {}).get("Error") or {}).get("Code", "")


def _reply(status, body):
    return {"statusCode": status,
            "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
            "body": json.dumps(body)}


def handler(event, context):
    ident = ((event or {}).get("requestContext") or {}).get("identity") or {}
    who = {"caller": ident.get("userArn") or ident.get("caller"), "account": ident.get("accountId"),
           "vpce": ident.get("vpceId"), "source_ip": ident.get("sourceIp")}
    try:
        secret = _secrets().get_secret_value(SecretId=SECRET_ARN)
        data = json.loads(secret.get("SecretString") or "{}")
    except Exception as exc:  # every failure mode maps to a status below; nothing else is raised to API Gateway
        code = _error_code(exc)
        if code in ("ResourceNotFoundException", "InvalidRequestException"):
            log.info(json.dumps({"outcome": "unavailable", "error": code, **who}))
            return _reply(404, {"status": "unavailable"})
        log.error(json.dumps({"outcome": "error", "error": code or type(exc).__name__, **who}))
        return _reply(502, {"status": "error"})
    key = data.get("api_key") if isinstance(data, dict) else None
    if not key:
        log.info(json.dumps({"outcome": "unavailable", "error": "no api_key in secret", **who}))
        return _reply(404, {"status": "unavailable"})
    log.info(json.dumps({"outcome": "issued", **who}))
    return _reply(200, {"endpoint": data.get("endpoint"), "model": data.get("model"), "api_key": key})
