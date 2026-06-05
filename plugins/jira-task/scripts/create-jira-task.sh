#!/usr/bin/env bash
#
# Jira Cloud에 Task 이슈를 생성한다.
#
# 사용법:
#   create-jira-task.sh --summary "제목" --description-file <본문파일경로>
#
# 필요한 환경변수:
#   JIRA_EMAIL        (필수) Atlassian 계정 이메일
#   JIRA_API_TOKEN    (필수) https://id.atlassian.com/manage-profile/security/api-tokens 에서 발급
#   JIRA_DOMAIN       (선택) 기본값: umproject-fixelsoft.atlassian.net
#   JIRA_PROJECT_KEY  (선택) 기본값: EXEB
#   JIRA_ISSUE_TYPE   (선택) 기본값: Task
#
# 성공 시 stdout 에 "생성된 티켓 키 + URL" 출력, 종료코드 0.
# 실패 시 stderr 에 에러 메시지 출력, 종료코드 1.

set -euo pipefail

DOMAIN="${JIRA_DOMAIN:-umproject-fixelsoft.atlassian.net}"
PROJECT_KEY="${JIRA_PROJECT_KEY:-EXEB}"
ISSUE_TYPE="${JIRA_ISSUE_TYPE:-Task}"

SUMMARY=""
DESCRIPTION_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)
      SUMMARY="${2:-}"
      shift 2
      ;;
    --description-file)
      DESCRIPTION_FILE="${2:-}"
      shift 2
      ;;
    *)
      echo "알 수 없는 인자: $1" >&2
      exit 1
      ;;
  esac
done

# --- 사전 검증 ---------------------------------------------------------------

err() { echo "❌ $1" >&2; }

missing=0
if [[ -z "${JIRA_EMAIL:-}" ]]; then
  err "환경변수 JIRA_EMAIL 이 설정되지 않았습니다."
  missing=1
fi
if [[ -z "${JIRA_API_TOKEN:-}" ]]; then
  err "환경변수 JIRA_API_TOKEN 이 설정되지 않았습니다. (발급: https://id.atlassian.com/manage-profile/security/api-tokens )"
  missing=1
fi
if [[ "$missing" -eq 1 ]]; then
  echo "" >&2
  echo "예시 설정 (~/.zshrc 등):" >&2
  echo "  export JIRA_EMAIL=\"you@example.com\"" >&2
  echo "  export JIRA_API_TOKEN=\"발급받은_토큰\"" >&2
  exit 1
fi

if [[ -z "$SUMMARY" ]]; then
  err "--summary (제목) 이 필요합니다."
  exit 1
fi
if [[ -z "$DESCRIPTION_FILE" || ! -r "$DESCRIPTION_FILE" ]]; then
  err "--description-file 경로를 읽을 수 없습니다: '${DESCRIPTION_FILE}'"
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "필수 명령어 '$cmd' 를 찾을 수 없습니다. 설치 후 다시 시도하세요."
    exit 1
  fi
done

DESCRIPTION="$(cat "$DESCRIPTION_FILE")"

# --- 요청 본문 생성 (Jira REST API v2: description 은 문자열) -----------------

PAYLOAD="$(jq -n \
  --arg project "$PROJECT_KEY" \
  --arg summary "$SUMMARY" \
  --arg description "$DESCRIPTION" \
  --arg issuetype "$ISSUE_TYPE" \
  '{
    fields: {
      project: { key: $project },
      summary: $summary,
      description: $description,
      issuetype: { name: $issuetype }
    }
  }')"

# --- API 호출 ----------------------------------------------------------------

API_URL="https://${DOMAIN}/rest/api/2/issue"

RESPONSE="$(curl -sS -w $'\n%{http_code}' \
  -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "$API_URL")" || {
    err "Jira 서버에 연결하지 못했습니다. (도메인: ${DOMAIN})"
    exit 1
  }

HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"
BODY="$(echo "$RESPONSE" | sed '$d')"

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  KEY="$(echo "$BODY" | jq -r '.key')"
  echo "✅ 티켓 생성 완료: ${KEY}"
  echo "🔗 https://${DOMAIN}/browse/${KEY}"
  exit 0
fi

# --- 에러 처리 ---------------------------------------------------------------

err "티켓 생성 실패 (HTTP ${HTTP_CODE})"
ERR_MSG="$(echo "$BODY" | jq -r '
  ([.errorMessages[]?] + [(.errors // {} | to_entries[] | "\(.key): \(.value)")])
  | if length > 0 then join("\n  - ") else empty end
' 2>/dev/null || true)"

if [[ -n "$ERR_MSG" ]]; then
  echo "  - ${ERR_MSG}" >&2
else
  echo "$BODY" >&2
fi

case "$HTTP_CODE" in
  401) echo "→ 인증 실패: JIRA_EMAIL / JIRA_API_TOKEN 을 확인하세요." >&2 ;;
  403) echo "→ 권한 없음: 해당 프로젝트(${PROJECT_KEY})에 이슈 생성 권한이 있는지 확인하세요." >&2 ;;
  404) echo "→ 경로/프로젝트를 찾을 수 없음: JIRA_DOMAIN / JIRA_PROJECT_KEY 를 확인하세요." >&2 ;;
esac

exit 1
