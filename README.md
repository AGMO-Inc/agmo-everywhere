<div align="center">

# Agmo Everywhere

**Claude Code 플러그인 — 8개 에이전트, 28개 온디맨드 스킬, Obsidian 중심 워크플로우**

[![Version](https://img.shields.io/badge/version-0.7.1-blue.svg)](https://github.com/AGMO-Inc/agmo-everywhere/releases/tag/v0.7.1)
[![Agents](https://img.shields.io/badge/agents-8-green.svg)](#에이전트-agents)
[![Skills](https://img.shields.io/badge/skills-28-orange.svg)](#스킬-카탈로그-skills)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)
[![Obsidian](https://img.shields.io/badge/hub-Obsidian-purple.svg)](#왜-obsidian인가-why-obsidian)

*오케스트레이터가 전문 에이전트에게 위임하고, Obsidian vault에 모든 지식을 축적하는 Claude Code 플러그인*

</div>

---

## 필수 도구 (Prerequisites)

| 도구 | 필요성 | 비고 |
|------|--------|------|
| **Claude Code** | 필수 | Anthropic 공식 CLI |
| **Obsidian** | 권장 | 미설치 시 경고 표시, vault 관련 기능 제한 |
| **Python 3** | 필수 | config 파일 JSON 파싱에 사용 (macOS 기본 설치) |
| **Node.js** | 필수 | statusLine(HUD) 설정에 사용 |
| **[Codex CLI](https://github.com/openai/codex)** | 선택 | 독립 검증자로 활용. 미설치 시 자동 스킵, 기존 워크플로우 영향 없음 |

### 스킬별 추가 도구

일부 스킬은 추가 도구가 필요합니다. 해당 스킬을 사용하지 않으면 설치하지 않아도 됩니다.

| 스킬 | 추가 도구 | 비고 |
|------|-----------|------|
| `implement-page` | [Playwright](https://playwright.dev/) | 브라우저 스크린샷 캡처. `npx playwright install chromium` |
| `implement-page-android` | [Paparazzi](https://github.com/cashapp/paparazzi) / [Roborazzi](https://github.com/takahirom/roborazzi) / [Compose Preview Screenshot Testing](https://developer.android.com/studio/preview/compose-screenshot-testing) | Compose Preview 스크린샷 캡처. 3종 중 1개 필수 |
| `implement-page`, `implement-page-android` | [Figma MCP Server](https://github.com/anthropics/claude-code/tree/main/packages/mcp-server-figma) | Figma 디자인 데이터 연동 |

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
- **메타데이터** (v0.7.0): 각 항목에 선택적으로 `confidence`, `source`, `ref` 태그를 추가할 수 있습니다.

### 예시

```markdown
# Learnings
- [2026-03-18] mock DB 테스트에서 prod 마이그레이션 실패를 감지 못함 → 통합 테스트는 실제 DB 사용 (confidence: high) (source: debugging)

# Decisions
- [2026-03-16] planner/architect/critic 에이전트 모델을 opus 고정 — 계획/분석에는 최상위 모델 필요 (confidence: high) (source: user)
```

---

## Codex 통합 (Optional)

[codex-plugin-cc](https://github.com/openai/codex-plugin-cc)가 설치된 환경에서 OpenAI Codex CLI를 독립 검증자로 활용합니다. Claude가 생성한 코드/플랜을 다른 모델이 교차 검증하여 self-review 편향을 줄입니다.

### 품질 게이트

| 게이트 | 스킬 | Codex 명령 | 역할 |
|--------|------|------------|------|
| Plan Review | `plan-review` Phase 1.5 | `/codex:adversarial-review` | 플랜 설계에 대한 adversarial challenge |
| Verification | `verification` | `/codex:review` | architect PASS 후 독립 코드 품질 리뷰 |
| Debugging | `debugging` Phase 4.5 | `/codex:rescue` | 3회 fix 실패 시 새로운 디버깅 관점 |

### 원칙

- **Codex는 품질 기준을 올릴 수만 있고 낮출 수 없음** — Agmo PASS + Codex BLOCK → FAIL
- **Graceful Degradation** — Codex 미설치, 인증 실패, 타임아웃 시 자동 스킵
- **HUD 표시** — 세션 시작 시 자동 감지하여 `codex:on` / `codex:off` 표시

---

## 안전 가드레일 (Safety)

`guard` 훅이 모든 Bash 명령 실행 전에 자동으로 위험 패턴을 검사합니다.

| 차단 대상 | 예시 |
|-----------|------|
| 재귀 삭제 | `rm -rf /`, `rm -rf ~` |
| DB 삭제 | `DROP TABLE`, `DROP DATABASE` |
| 강제 푸시 | `git push --force main` |
| 하드 리셋 | `git reset --hard main` |

공백 변형, 플래그 순서 변경 등 기본 우회 패턴에도 대응합니다. 차단 시 사유를 명시하고 실행을 중단합니다.

---

## 에이전트 (Agents)

| Agent | Role | Model |
|-------|------|-------|
| `executor` | 코드 작성 및 수정 | haiku / sonnet / opus (라우팅) |
| `explore` | 코드베이스 탐색 | haiku (기본) |
| `archivist` | Obsidian vault 작업 | haiku (기본) |
| `frontend` | 프론트엔드 품질 검증 (visual, accessibility, responsive) | opus (고정) |
| `android-specialist` | Android 프론트엔드 품질 검증 (visual, accessibility, responsive) | opus (고정) |
| `architect` | 분석, 검증, 디버깅 | opus (고정) |
| `planner` | 계획 수립 | opus (고정) |
| `critic` | 리뷰 및 비평 | opus (고정) |

---

## 스킬 카탈로그 (Skills)

| 카테고리 | 스킬 |
|----------|------|
| **워크플로우** | `brainstorming`, `plan`, `plan-review`, `execute`, `ralph` |
| **품질** | `tdd`, `verification`, `code-review`, `debugging`, `accessibility` |
| **분석** | `retro`, `security-audit`, `benchmark` |
| **Obsidian** | `save-plan`, `save-impl`, `save-note`, `vault-search`, `note-to-issue`, `wisdom` |
| **Git** | `git-workflow` |
| **Figma** | `implement-page`, `implement-page-android` |
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
