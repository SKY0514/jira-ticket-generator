# jira-task-plugin

기능/개선 요청을 정해진 포맷으로 정리한 뒤, 확인을 거쳐 **Jira(Cloud)에 `Task` 티켓을 자동 생성**하는 Claude Code 플러그인입니다. 주로 개발자가 기능/개선 요청을 빠르게 티켓화할 때 사용합니다.

## 설치

Claude Code 에서:

```
/plugin marketplace add SKY0514/jira-task-plugin
/plugin install jira-task
```

## 사전 설정 (환경변수)

티켓 생성을 위해 Jira 인증 정보가 필요합니다. 셸 설정(`~/.zshrc`, `~/.bashrc` 등)에 추가하세요.

```bash
export JIRA_EMAIL="you@example.com"
export JIRA_API_TOKEN="발급받은_API_토큰"
```

API 토큰은 여기서 발급합니다 → https://id.atlassian.com/manage-profile/security/api-tokens

선택 환경변수 (다른 팀/프로젝트에서 쓸 때 덮어쓰기):

| 환경변수 | 필수 | 기본값 |
|---|---|---|
| `JIRA_EMAIL` | ✅ | — |
| `JIRA_API_TOKEN` | ✅ | — |
| `JIRA_DOMAIN` | ❌ | `umproject-fixelsoft.atlassian.net` |
| `JIRA_PROJECT_KEY` | ❌ | `EXEB` |
| `JIRA_ISSUE_TYPE` | ❌ | `Task` |

필수 의존성: `curl`, `jq`

## 사용법

```
/jira-task 로그인 화면에 자동완성 기능 추가해줘
```

- 인자로 요청을 설명하면, Claude 가 포맷에 맞춰 **초안(제목 + 본문)** 을 작성해 보여줍니다.
- 인자 없이 `/jira-task` 만 입력하면, 현재 대화·코드 변경 맥락을 보고 초안을 작성합니다.
- 초안을 확인하고 **승인하면** 그때 티켓이 생성됩니다. (승인 전에는 생성되지 않습니다.)

## 티켓 포맷

```
제목: [기능] 또는 [개선] 한 줄 요약

h2. 배경 / 목적
h2. 요청 내용
h2. 완료 조건 (AC)
h2. 참고 자료
```

## 구조

```
.claude-plugin/marketplace.json     # 마켓플레이스 정의
plugins/jira-task/
├── .claude-plugin/plugin.json      # 플러그인 매니페스트
├── commands/jira-task.md           # /jira-task 워크플로우
└── scripts/create-jira-task.sh     # Jira REST API 호출
```
