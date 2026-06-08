#!/usr/bin/env bash
#
# Jira Cloud에 이슈를 생성한다.
#
# 사용법:
#   create-jira-ticket.sh --summary "제목" --description-file <본문파일경로> \
#     [--issue-type Task] [--priority Medium] [--labels "a,b,c"] [--assignee "이메일/이름"]
#
#   --priority  기본값 Medium (Highest/High/Medium/Low/Lowest)
#   --labels    쉼표 구분, 미지정 시 없음
#   --assignee  이메일/이름으로 검색해 accountId 변환. 미지정 시 인증 계정(나)에게 할당
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
PRIORITY="Medium"   # 미지정 시 기본값
LABELS=""           # 쉼표 구분, 미지정 시 없음
ASSIGNEE=""         # 이메일/이름, 미지정 시 인증 계정(나)에게 할당

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
    --issue-type)
      ISSUE_TYPE="${2:-}"
      shift 2
      ;;
    --priority)
      PRIORITY="${2:-}"
      shift 2
      ;;
    --labels)
      LABELS="${2:-}"
      shift 2
      ;;
    --assignee)
      ASSIGNEE="${2:-}"
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

# 인증된 GET 호출 헬퍼
jira_get() {
  curl -sS -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" -H "Accept: application/json" "$1"
}

# --- 담당자(assignee) accountId 해석 -----------------------------------------
# 미지정이면 인증 계정(나)에게 할당. 지정 시 사용자 검색으로 accountId 변환.

ACCOUNT_ID=""
if [[ -z "$ASSIGNEE" ]]; then
  ACCOUNT_ID="$(jira_get "https://${DOMAIN}/rest/api/2/myself" | jq -r '.accountId // empty')"
  if [[ -z "$ACCOUNT_ID" ]]; then
    err "본인 계정 정보를 가져오지 못했습니다. (인증 정보를 확인하세요)"
    exit 1
  fi
else
  SEARCH_ENC="$(jq -rn --arg q "$ASSIGNEE" '$q|@uri')"
  RESULT="$(jira_get "https://${DOMAIN}/rest/api/2/user/search?query=${SEARCH_ENC}")"
  COUNT="$(echo "$RESULT" | jq 'length')"
  if [[ "$COUNT" == "0" ]]; then
    err "담당자 '${ASSIGNEE}' 에 해당하는 사용자를 찾지 못했습니다."
    exit 1
  elif [[ "$COUNT" != "1" ]]; then
    err "담당자 '${ASSIGNEE}' 검색 결과가 여러 명입니다. 더 구체적으로(이메일) 지정하세요:"
    echo "$RESULT" | jq -r '.[] | "  - \(.displayName) <\(.emailAddress // "이메일비공개")>"' >&2
    exit 1
  fi
  ACCOUNT_ID="$(echo "$RESULT" | jq -r '.[0].accountId')"
fi

# --- 요청 본문 생성 (Jira REST API v2: description 은 문자열) -----------------

# 레이블: 쉼표로 분리해 배열화 (공백 제거, 빈 항목 제외)
LABELS_JSON="$(jq -rn --arg s "$LABELS" '
  ($s | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0)))
')"

PAYLOAD="$(jq -n \
  --arg project "$PROJECT_KEY" \
  --arg summary "$SUMMARY" \
  --arg description "$DESCRIPTION" \
  --arg issuetype "$ISSUE_TYPE" \
  --arg priority "$PRIORITY" \
  --arg accountId "$ACCOUNT_ID" \
  --argjson labels "$LABELS_JSON" \
  '{
    fields: ({
      project: { key: $project },
      summary: $summary,
      description: $description,
      issuetype: { name: $issuetype },
      assignee: { id: $accountId }
    }
    + (if ($priority | length) > 0 then { priority: { name: $priority } } else {} end)
    + (if ($labels | length) > 0 then { labels: $labels } else {} end))
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
  400) echo "→ 필드 값 오류: 우선순위 이름(${PRIORITY}) 또는 레이블/담당자가 프로젝트에서 유효한지 확인하세요." >&2 ;;
  401) echo "→ 인증 실패: JIRA_EMAIL / JIRA_API_TOKEN 을 확인하세요." >&2 ;;
  403) echo "→ 권한 없음: 해당 프로젝트(${PROJECT_KEY})에 이슈 생성 권한이 있는지 확인하세요." >&2 ;;
  404) echo "→ 경로/프로젝트를 찾을 수 없음: JIRA_DOMAIN / JIRA_PROJECT_KEY 를 확인하세요." >&2 ;;
esac

exit 1
