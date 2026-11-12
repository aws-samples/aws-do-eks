"""A Strands agent on the key-gated endpoint, reading the three values from SSM (the parameters get-modelkey.sh --ssm
stores). Runs unchanged on Amazon Bedrock AgentCore Runtime when its execution role may ssm:GetParameter them.
pip install strands-agents strands-agents[openai] boto3"""
import boto3
from strands import Agent
from strands.models.openai import OpenAIModel

ssm = boto3.client("ssm")


def param(name, decrypt=False):
    return ssm.get_parameter(Name=f"/workshop/nemotron/{name}", WithDecryption=decrypt)["Parameter"]["Value"]


model = OpenAIModel(client_args={"api_key": param("api_key", True), "base_url": param("endpoint")},
                    model_id=param("model"), params={"max_tokens": 512})
Agent(model=model)("Describe EFA in two sentences.")
