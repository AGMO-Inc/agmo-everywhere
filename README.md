# Agmo Everywhere

Claude Code 플러그인 — 6개 에이전트, 22개 온디맨드 스킬, Obsidian 중심 워크플로우

**v0.3.6**

---

## 필수 도구 (Prerequisites)

| 도구 | 필요성 | 비고 |
|------|--------|------|
| **Claude Code** | 필수 | Anthropic 공식 CLI |
| **Obsidian** | 권장 | 미설치 시 경고 표시, vault 관련 기능 제한 |
| **Python 3** | 필수 | config 파일 JSON 파싱에 사용 (macOS 기본 설치) |
| **Node.js** | 필수 | statusLine(HUD) 설정에 사용 |

---

## 설치 가이드 (Installation)

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add https://github.com/AGMO-Inc/agmo-everywhere

# 2. 플러그인 설치
claude plugin install agmo

# 3. 초기 설정 (새 세션 시작 후)
# Claude Code에서 아래와 같이 입력
/setup
```

`setup` 실행 시 다음 작업이 자동으로 수행됩니다.

- Obsidian vault 경로 설정 → `~/.agmo/config` 저장
- statusLine(HUD) 자동 구성
- 공유 디렉토리 및 wisdom 파일 초기화

---

## 핵심 원칙 (Core Principles)

1. **Conductor, not Performer** — 오케스트레이터는 직접 코드를 작성하지 않고 전문 에이전트에게 위임합니다.
2. **Evidence before Claims** — "완료"라고 선언하기 전에 반드시 검증 증거를 확보합니다.
3. **YAGNI** — 명시적으로 요청된 것만 구현합니다. 추측에 의한 기능 추가를 금지합니다.
4. **Token Efficiency** — 카테고리 라우팅으로 작업 복잡도에 맞는 모델을 자동 선택합니다. (`haiku` / `sonnet` / `opus`)
5. **Obsidian is the Hub** — 모든 문서(플랜, 설계, 구현 기록)의 원본은 Obsidian vault에 저장합니다.

---

## 왜 Obsidian인가? (Why Obsidian)

**세션 간 기억 연속성** — Claude Code는 세션이 끝나면 컨텍스트가 사라집니다. Vault에 플랜/설계/구현이 남아있으므로 새 세션에서도 이전 작업을 이어갈 수 있습니다.

**프로젝트 간 컨텍스트 공유** — brainstorming이나 plan 스킬이 자동으로 vault를 탐색하여 관련 설계 문서, 과거 결정사항을 참조합니다. 프로젝트 A에서 내린 결정이 프로젝트 B 작업에도 반영됩니다.

**Wisdom 축적** — `decisions.md`, `learnings.md`, `issues.md`가 매 세션 시작 시 자동 로드됩니다. 축적된 경험이 다음 세션에도 이어져, 시간이 지날수록 에이전트가 팀의 맥락을 더 잘 이해하게 됩니다.

**양방향 링크로 추적성 확보** — 설계 → 플랜 → 구현 간 wikilink가 자동 생성됩니다. Obsidian 그래프 뷰에서 문서 간 관계를 한눈에 파악할 수 있습니다.

**사람과 에이전트가 같은 문서를 공유** — 마크다운 기반이므로 사용자가 직접 열어서 플랜을 수정하거나 메모를 추가할 수 있습니다.

---

## Wisdom 시스템

Wisdom은 프로젝트에서 축적된 **학습, 결정, 이슈**를 기록하고 자동 활용하는 시스템입니다.

### 구조

```
{vault_root}/
├── {project}/wisdom/
│   ├── learnings.md   # 프로젝트에서 얻은 교훈
│   ├── decisions.md   # 설계/아키텍처 결정 사항
│   └── issues.md      # 알려진 문제, 미해결 이슈
└── shared/wisdom/
    ├── learnings.md   # 프로젝트 공통 교훈
    ├── decisions.md   # 공통 결정 사항
    └── issues.md      # 공통 이슈
```

### 동작 방식

- **자동 로드**: 매 세션 시작 시 `session-start` 훅이 프로젝트 wisdom → 공유 wisdom 순으로 읽어 컨텍스트에 주입합니다.
- **수동 기록**: "기억해", "이거 기록해"라고 말하면 `wisdom` 스킬이 해당 내용을 분류하여 저장합니다.
- **자동 기록**: 디버깅이나 검증 과정에서 중요한 발견이 있으면 저장을 제안합니다.

### 예시

```markdown
# Learnings
- [2026-03-18] mock DB 테스트에서 prod 마이그레이션 실패를 감지 못함 → 통합 테스트는 실제 DB 사용

# Decisions
- [2026-03-16] planner/architect/critic 에이전트 모델을 opus 고정 — 계획/분석에는 최상위 모델 필요
```

---

## 에이전트 (Agents)

| Agent | Role | Model |
|-------|------|-------|
| `executor` | 코드 작성 및 수정 | haiku / sonnet / opus (라우팅) |
| `explore` | 코드베이스 탐색 | haiku (기본) |
| `archivist` | Obsidian vault 작업 | haiku (기본) |
| `architect` | 분석, 검증, 디버깅 | opus (고정) |
| `planner` | 계획 수립 | opus (고정) |
| `critic` | 리뷰 및 비평 | opus (고정) |

---

## 스킬 카탈로그 (Skills)

| 카테고리 | 스킬 |
|----------|------|
| **워크플로우** | `brainstorming`, `plan`, `plan-review`, `execute`, `ralph` |
| **품질** | `tdd`, `verification`, `code-review`, `debugging`, `accessibility` |
| **Obsidian** | `save-plan`, `save-impl`, `save-note`, `vault-search`, `note-to-issue`, `wisdom` |
| **Git** | `git-workflow` |
| **오케스트레이션** | `parallel`, `cancel` |
| **메타** | `setup`, `plugin-review` |

---

## 워크플로우 가이드 (Recommended Workflows)

### 기본 워크플로우: 아이디어 → 설계 → 계획 → 실행

```
"이런 기능을 만들고 싶어"  →  brainstorming
→ 설계 승인
→ "플랜 만들어줘"          →  plan
→ [선택] "플랜 리뷰해줘"  →  plan-review
→ "실행해줘"               →  execute
→ 자동 검증 + Obsidian 저장
```

### 빠른 실행: 명확한 요청

```
"이 버그 수정해줘"    →  직접 실행 (Light 작업)
"이 기능 구현해줘"   →  plan → execute (Heavy 작업)
```

### TDD 워크플로우

```
"TDD로 구현해줘"  →  테스트 먼저 → 구현 → 리팩토링
```

### Git 워크플로우

```
"커밋해줘"    →  git-workflow 스킬
"PR 만들어줘" →  git-workflow 스킬
```

---

## 설정 (Configuration)

| 항목 | 값 |
|------|----|
| config 파일 | `~/.agmo/config` |
| 환경변수 | `AGMO_VAULT_ROOT` (config보다 우선 적용) |
| 상태 디렉토리 | `~/.agmo/state/` |

---

## License

MIT
