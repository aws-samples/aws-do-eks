"""openai SDK against the key-gated endpoint. Reads OPENAI_BASE_URL / OPENAI_API_KEY / MODEL from the environment
(see ../README.md section 4). pip install openai"""
import os

from openai import OpenAI

client = OpenAI()  # base_url and api_key from OPENAI_BASE_URL / OPENAI_API_KEY
with client.chat.completions.create(
        model=os.environ["MODEL"], stream=True, max_tokens=256,
        messages=[{"role": "user", "content": "Describe EFA in two sentences."}]) as stream:
    for chunk in stream:
        print(chunk.choices[0].delta.content or "", end="", flush=True)
print()
