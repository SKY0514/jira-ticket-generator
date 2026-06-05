# jira-task-plugin

기능/개선 요청을 정해진 포맷으로 정리한 뒤, 확인을 거쳐 **Jira(Cloud)에 `Task` 티켓을 자동 생성**하는 Claude Code 플러그인입니다. 주로 개발자가 기능/개선 요청을 빠르게 티켓화할 때 사용합니다.

## 팀원용 설치 가이드

처음 쓰는 사람은 아래 순서대로 한 번만 설정하면 됩니다.

### 1단계 — Jira API 토큰 발급 (최초 1회)

1. https://id.atlassian.com/manage-profile/security/api-tokens 접속
2. **Create API token** → 이름 입력 → 생성
3. 나온 토큰(`ATATT...`)을 복사 (화면을 벗어나면 다시 볼 수 없습니다)

### 2단계 — 인증 정보 등록 (최초 1회)

터미널에서 본인 정보로 실행:

```bash
echo 'export JIRA_EMAIL="본인 Atlassian 이메일"' >> ~/.zshenv
echo 'export JIRA_API_TOKEN="복사한 토큰"' >> ~/.zshenv
```

> ⚠️ `~/.zshrc`가 아니라 **`~/.zshenv`** 에 넣어야 Claude의 비대화형 셸이 자동 인식합니다.
> bash 사용자는 `~/.bash_profile` 또는 `~/.profile` 에 넣으세요.

설정 후 터미널을 새로 열거나 `source ~/.zshenv` 를 한 번 실행합니다.

### 3단계 — 플러그인 설치 (최초 1회)

**터미널에서 `claude` 실행** 후, 그 안에서:

```
/plugin marketplace add SKY0514/jira-task-plugin
/plugin install jira-task
```

> 💡 `/plugin` 명령은 **터미널 Claude Code**에서만 동작합니다 (VS Code 확장에서는 불가).
> 단, 터미널에서 한 번 설치하면 VS Code 확장에서도 `/jira-task`가 같이 잡힙니다.

필수 의존성: `curl`, `jq` (없으면 `brew install jq`)

## 사용법

Claude Code(터미널 또는 VS Code)에서:

```
/jira-task 로그인 화면에 자동완성 기능 추가해줘
```

1. Claude가 포맷에 맞춰 **초안(제목 + 본문)** 을 보여줍니다.
2. "이대로 생성할까요?" 확인을 거쳐
3. **승인하면** `EXEB` 프로젝트에 `Task` 티켓이 생성되고 링크를 줍니다. (승인 전에는 생성되지 않습니다.)

> 인자 없이 `/jira-task` 만 입력하면, 현재 대화·코드 변경 맥락을 보고 초안을 작성합니다.

## 환경변수

| 환경변수 | 필수 | 기본값 |
|---|---|---|
| `JIRA_EMAIL` | ✅ | — |
| `JIRA_API_TOKEN` | ✅ | — |
| `JIRA_DOMAIN` | ❌ | `umproject-fixelsoft.atlassian.net` |
| `JIRA_PROJECT_KEY` | ❌ | `EXEB` |
| `JIRA_ISSUE_TYPE` | ❌ | `Task` |

> 다른 회사/프로젝트 Jira에 쓰려면 `JIRA_DOMAIN`, `JIRA_PROJECT_KEY` 를 덮어쓰면 됩니다.

## 자주 묻는 것

| 상황 | 해결 |
|---|---|
| "환경변수가 설정되지 않았습니다" | 2단계 `~/.zshenv` 설정 확인 → 터미널 새로 열기 |
| 인증 실패(401) | 이메일/토큰 오타 확인, 토큰 재발급 |
| 권한 없음(403) | 해당 Jira 프로젝트에 이슈 생성 권한이 있는지 확인 |
| `/plugin` 안 됨 | VS Code 확장이 아니라 **터미널 Claude Code**에서 실행 |

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
