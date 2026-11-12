# Consumer side: how an AWS account (for example a Workshop Studio event account) obtains and uses the model key

This folder is documentation and snippets only - it creates nothing. The two deployable parts are
[`../gateway`](../gateway) (the key gate in front of the frontend) and [`../modelkey-api`](../modelkey-api) (the private
API that hands out the key). What follows is what the *calling* side needs, in order.

## 1. Reach the private API

The API is `PRIVATE`: it has no public hostname and answers only through an **execute-api interface VPC endpoint** in the
caller's VPC, in the API's region (`API_REGION`, default `us-west-2`). Create one with private DNS enabled - the
default `*.execute-api.<region>.amazonaws.com` names then resolve to the endpoint inside the VPC:

```yaml
# CloudFormation fragment for the calling VPC (a Workshop Studio template, a CDK stack, a console click - any of them)
APIInterfaceEndpoint:
  Type: AWS::EC2::VPCEndpoint
  Properties:
    VpcId: !Ref Vpc
    ServiceName: !Sub com.amazonaws.${AWS::Region}.execute-api
    VpcEndpointType: Interface
    PrivateDnsEnabled: true
    SubnetIds: [!Ref PrivateSubnet1, !Ref PrivateSubnet2]
    SecurityGroupIds: [!Ref EndpointSecurityGroup]   # allows 443 from the callers
```

If the API owner set `SOURCE_VPCE_IDS`, send them this endpoint's id (`vpce-...`); if they set `PRINCIPAL_ORG_ID`, the
calling account must belong to that AWS Organization.

## 2. Allow the caller to invoke

The calling role (an instance profile, a Lambda role, a workshop participant role) needs one statement; the `InvokeArn`
output of the API stack is the resource:

```json
{"Effect": "Allow", "Action": "execute-api:Invoke",
 "Resource": "arn:aws:execute-api:us-west-2:<api-account-id>:<api-id>/dev/POST/modelkey"}
```

Cross-account works because the API's resource policy allows `execute-api:Invoke` on that method for `Principal: "*"`
(optionally narrowed by organization id and/or endpoint id); IAM on the caller side plus the private network path are
the two gates every call passes.

## 3. Call POST /modelkey (SigV4)

From an instance or notebook inside the VPC, with the role's credentials in the environment or the instance profile:

```bash
URL=https://<api-id>.execute-api.us-west-2.amazonaws.com/dev/modelkey     # the InvokeUrl output

# awscurl (pip install awscurl) signs with the credentials the AWS CLI sees
awscurl --service execute-api --region us-west-2 -X POST "$URL"

# or curl >= 7.75 with the current session credentials
eval "$(aws configure export-credentials --format env)"
curl -s -X POST "$URL" --aws-sigv4 "aws:amz:us-west-2:execute-api" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" -H "x-amz-security-token: $AWS_SESSION_TOKEN"
```

Answer: `200 {"endpoint": "https://<host>/v1", "model": "<served model name>", "api_key": "<48 chars>"}`;
`404 {"status": "unavailable"}` means the key is not being handed out right now (the event is over, the endpoint is
down) - a provisioning step should treat that as "skip", not as a failure; `403` means the IAM statement of step 2 or
the network path of step 1 is missing. [`get-modelkey.sh`](get-modelkey.sh) wraps the awscurl call and, with
`--ssm`, stores the three values as SSM parameters for the attendees (`/workshop/nemotron/endpoint`, `.../model`,
`.../api_key` as a SecureString).

A workshop provisioning step that runs with the right role (a CloudFormation custom resource Lambda in the VPC, the
bootstrap of the attendee's IDE instance, a one-shot EC2 user-data step) does exactly steps 3 and the `--ssm` store;
how it is wired into a given workshop template is that workshop's business, not this folder's.

## 4. Attendee snippets

The endpoint is OpenAI-compatible (NVIDIA Dynamo frontend). With the three values in the environment:

```bash
export OPENAI_BASE_URL=$(aws ssm get-parameter --name /workshop/nemotron/endpoint --query Parameter.Value --output text)
export OPENAI_API_KEY=$(aws ssm get-parameter --name /workshop/nemotron/api_key --with-decryption --query Parameter.Value --output text)
export MODEL=$(aws ssm get-parameter --name /workshop/nemotron/model --query Parameter.Value --output text)
```

- [`snippets/chat.sh`](snippets/chat.sh) - curl: a streamed chat completion, a short non-streamed one, and the
  negative control (no key -> 403).
- [`snippets/openai_client.py`](snippets/openai_client.py) - the `openai` SDK, streaming.
- [`snippets/strands_agent.py`](snippets/strands_agent.py) - a Strands agent on the same endpoint (runs unchanged on
  Amazon Bedrock AgentCore Runtime; its execution role needs `ssm:GetParameter` on the three parameters).

**Stream, or keep `max_tokens` <= 512 when you do not.** A streamed answer sends a chunk every ~90 ms, so no idle
timeout is approached. A non-streamed answer is one write at the end: a 512-token answer takes ~45 s on one H200 node
and passes, but a shared load balancer in front of the ingress controller may close an idle connection at 60 s, so
longer non-streamed answers fail at the client with a reset.

## What the key is, honestly

A shared secret for one event, delivered only to callers that (1) hold an AWS identity allowed `execute-api:Invoke` on
the method and (2) reach the private API through an execute-api endpoint in its region; the gateway's `stop.sh` (or a
`rotate.sh` + `secret-sync.sh`) invalidates every copy at once. It identifies the *event*, not the attendee: per-user
keys, budgets or request logs need a key-aware proxy (for example LiteLLM) in place of the key gate.
