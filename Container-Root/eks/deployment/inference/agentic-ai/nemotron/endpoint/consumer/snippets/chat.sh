#!/bin/bash

# Attendee-side curl against the key-gated endpoint. Expects OPENAI_BASE_URL, OPENAI_API_KEY and MODEL in the
# environment (see ../README.md section 4).

: "${OPENAI_BASE_URL:?}" "${OPENAI_API_KEY:?}" "${MODEL:?}"

echo "--- streaming (recommended)"
curl -sN "${OPENAI_BASE_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" -H "Content-Type: application/json" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Describe EFA in two sentences.\"}],\"max_tokens\":256,\"stream\":true}"
echo

echo "--- non-streaming: keep max_tokens <= 512"
curl -s "${OPENAI_BASE_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" -H "Content-Type: application/json" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello.\"}],\"max_tokens\":64}"
echo

echo "--- negative control: without the key everyone gets 403"
curl -s -o /dev/null -w '%{http_code}\n' "${OPENAI_BASE_URL}/models"
