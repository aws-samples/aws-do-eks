#!/usr/bin/env python3
"""Structural checks of template.yaml (no AWS call): the inline Lambda code equals lambda/model_key/lambda_function.py,
fits the 4096-byte ZipFile limit, the API is PRIVATE, the method is POST + AWS_IAM + AWS_PROXY, the resource policy
allows execute-api:Invoke on that method only, the Lambda role reads one secret only, the secret is generated with no
punctuation or uppercase (safe inside an nginx string and an Authorization header). Needs PyYAML.
Run: python3 test/check_template.py  (exit 0 = all checks pass).
"""
import pathlib
import re
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
TEMPLATE = HERE.parent / "template.yaml"
SRC = HERE.parent / "lambda" / "model_key" / "lambda_function.py"


class Cfn(yaml.SafeLoader):
    pass


def _tag(loader, suffix, node):
    if isinstance(node, yaml.ScalarNode):
        return {"Fn::" + suffix: loader.construct_scalar(node)}
    if isinstance(node, yaml.SequenceNode):
        return {"Fn::" + suffix: loader.construct_sequence(node)}
    return {"Fn::" + suffix: loader.construct_mapping(node)}


Cfn.add_multi_constructor("!", lambda loader, suffix, node: _tag(loader, suffix, node))

checks = []


def check(name, ok):
    checks.append(ok)
    print(("PASS  " if ok else "FAIL  ") + name)


t = yaml.load(TEMPLATE.read_text(), Loader=Cfn)
res = t["Resources"]
zipfile = res["ModelKeyFunction"]["Properties"]["Code"]["ZipFile"]
check("inline ZipFile equals lambda/model_key/lambda_function.py", zipfile.rstrip("\n") == SRC.read_text().rstrip("\n"))
check("inline ZipFile is under the 4096-byte limit", len(zipfile.encode()) <= 4096)
check("Lambda runtime python3.12, handler index.handler", res["ModelKeyFunction"]["Properties"]["Runtime"] == "python3.12" and res["ModelKeyFunction"]["Properties"]["Handler"] == "index.handler")
check("Lambda env SECRET_ARN refers to the secret", res["ModelKeyFunction"]["Properties"]["Environment"]["Variables"]["SECRET_ARN"] == {"Fn::Ref": "ModelKeySecret"})
check("REST API endpoint type PRIVATE only", res["ModelKeyApi"]["Properties"]["EndpointConfiguration"]["Types"] == ["PRIVATE"])
m = res["ModelKeyMethod"]["Properties"]
check("method POST with AuthorizationType AWS_IAM", m["HttpMethod"] == "POST" and m["AuthorizationType"] == "AWS_IAM")
check("integration AWS_PROXY to the Lambda", m["Integration"]["Type"] == "AWS_PROXY" and "ModelKeyFunction.Arn" in m["Integration"]["Uri"]["Fn::Sub"])
stmts = res["ModelKeyApi"]["Properties"]["Policy"]["Statement"]
check("resource policy: one Allow statement for execute-api:Invoke", len(stmts) == 1 and stmts[0]["Effect"] == "Allow" and stmts[0]["Action"] == "execute-api:Invoke")
check("resource policy scoped to POST/modelkey of the stage", stmts[0]["Resource"] == {"Fn::Sub": "execute-api:/${StageName}/POST/modelkey"})
cond = stmts[0]["Condition"]["Fn::If"]
check("resource policy condition keyed on HasOrgId / HasVpce (optional org id and VPC endpoint pins)", cond[0] == "HasOrgId" and "Fn::If" in cond[1] and "Fn::If" in cond[2])
check("conditions HasOrgId and HasVpce declared", set(t["Conditions"]) == {"HasOrgId", "HasVpce"})
pol = res["ModelKeyFunctionRole"]["Properties"]["Policies"]
inline = [s for p in pol for s in p["PolicyDocument"]["Statement"]]
check("Lambda role inline policy: exactly one statement, secretsmanager:GetSecretValue on the secret", len(inline) == 1 and inline[0]["Action"] == "secretsmanager:GetSecretValue" and inline[0]["Resource"] == {"Fn::Ref": "ModelKeySecret"})
check("Lambda role managed policy: basic execution only", len(res["ModelKeyFunctionRole"]["Properties"]["ManagedPolicyArns"]) == 1 and "AWSLambdaBasicExecutionRole" in res["ModelKeyFunctionRole"]["Properties"]["ManagedPolicyArns"][0]["Fn::Sub"])
g = res["ModelKeySecret"]["Properties"]["GenerateSecretString"]
check("secret generated in-account: api_key, 48 chars, no punctuation, no uppercase", g["GenerateStringKey"] == "api_key" and g["PasswordLength"] == 48 and g["ExcludePunctuation"] is True and g["ExcludeUppercase"] is True)
check("secret template carries endpoint and model", "endpoint" in g["SecretStringTemplate"]["Fn::Sub"] and "model" in g["SecretStringTemplate"]["Fn::Sub"])
perm = res["ModelKeyInvokePermission"]["Properties"]
check("Lambda permission limited to this API's POST/modelkey", perm["Principal"] == "apigateway.amazonaws.com" and perm["SourceArn"]["Fn::Sub"].endswith("${ModelKeyApi}/*/POST/modelkey"))
check("stage created from the deployment", res["ModelKeyStage"]["Properties"]["DeploymentId"] == {"Fn::Ref": "ModelKeyDeployment"} and res["ModelKeyStage"]["Properties"]["StageName"] == {"Fn::Ref": "StageName"})
check("outputs ApiId, InvokeUrl, InvokeArn, SecretArn", {"ApiId", "InvokeUrl", "InvokeArn", "SecretArn"} <= set(t["Outputs"]))
tt = TEMPLATE.read_text()
check("no hard-coded account id (12-digit run), API id (<id>.execute-api.) or https host other than the example default / a ${} reference",
      not re.search(r"(?<![0-9A-Za-z])[0-9]{12}(?![0-9])", tt)
      and not re.search(r"\b[a-z0-9]{10}\.execute-api\.", tt)
      and all(h.startswith("${") or h.endswith(".example.com") for h in re.findall(r"https://([^/\s]+)", tt)))
params = set(t["Parameters"])
check("parameters SecretName, EndpointUrl, ModelId, StageName, PrincipalOrgId, SourceVpceIds", params == {"SecretName", "EndpointUrl", "ModelId", "StageName", "PrincipalOrgId", "SourceVpceIds"})

n_ok = sum(1 for c in checks if c)
print(f"VERDICT {'PASS' if n_ok == len(checks) else 'FAIL'} {n_ok}/{len(checks)}")
sys.exit(0 if n_ok == len(checks) else 1)
