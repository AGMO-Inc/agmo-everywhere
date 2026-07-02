# Changelog

All notable changes to the agmo Claude Code plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.8.5] - 2026-07-02

### Changed
- 모델 고정 에이전트 중 planner·critic만 `claude-opus-4-8` → `claude-fable-5` 선택 전환 (architect/frontend/android-specialist 및 complex 티어는 opus 유지). 사유: Fable 5 주간 한도 50% 상한(7/7까지)·빠른 소진 대응

## [0.8.4] - 2026-06-24

### Added
- `debt` 스킬 신설 — 코드의 `// debt:` / `# debt:` 마커를 수집해 ledger로 만드는 읽기 전용 one-shot 스킬. 요청 시 Obsidian vault `{PROJECT}/debt-ledger.md`에 저장하고, `upgrade:` 트리거 충족 항목은 `agmo:plan`으로 넘길지 제안하는 느슨한 핸드오프 포함 (`skills/debt/`)
- executor에 `## Solution Discipline` 신설 — ponytail 게으름 사다리(7-rung) 주입: YAGNI → 코드베이스 재사용 → stdlib → native 플랫폼 기능 → 기존 의존성 → one-liner → 최소 코드. 근본원인 수정(모든 호출자 grep), `// debt:` 마커 컨벤션(Rule 3 예외), 단순화 금지선(trust-boundary 검증·데이터손실 방지·보안·접근성) 포함 (`agents/executor.md`)
- code-review / critic에 과잉엔지니어링 렌즈 — `delete:` `stdlib:` `native:` `yagni:` `shrink:` 태그 포맷 + `net: -N lines possible`. correctness/security/performance와 별개 축이며 IMPORTANT/MINOR로만 분류(zero-CRITICAL=APPROVE 규칙 유지) (`skills/code-review/`, `agents/critic.md`)

### Changed
- planner Rule 6(YAGNI) 강화 — TODO 분해 시 재사용/stdlib/native/기존코드 우선, 단일구현 추상화·아무도 안 읽는 config·단일호출자 레이어 계획 금지 (`agents/planner.md`)
- brainstorming — Propose Approaches에 "가장 게으른(최소한의) 접근 우선" 추가, Scope boundaries(YAGNI)에 게으름 사다리 적용 (`skills/brainstorming/`)
- 스킬 카탈로그 카운트 29 → 30 (plugin.json / marketplace.json / README / using-plugin)

## [0.8.3] - 2026-06-15

### Changed
- 모델 고정 에이전트(planner/architect/critic/frontend/android-specialist)를 `claude-fable-5`에서 `claude-opus-4-8`로 환원
- 카테고리 라우팅 complex 티어를 fable → opus로 전환 (executor/explore), 관련 스킬 문서(using-plugin, category-routing, execute, implement-page, implement-page-android, plugin-review) 및 README 동기화
- 버전 0.8.3 (plugin.json / marketplace.json / README)

## [0.8.2] - 2026-06-10

### Changed
- 모델 고정 에이전트(planner/architect/critic/frontend/android-specialist)를 `claude-opus-4-8`에서 `claude-fable-5`로 업그레이드
- 카테고리 라우팅 complex 티어를 opus → fable로 전환 (executor/explore), 관련 스킬 문서(using-plugin, category-routing, execute, implement-page, implement-page-android, plugin-review) 및 README 동기화
- 버전 0.8.2 (plugin.json / marketplace.json / README)

## [0.8.1] - 2026-06-01

### Changed
- session-start llm-wiki 주입을 eager 본문 덤프에서 lazy manifest(지도) 포인터로 전환 — 기본 모드 `manifest`, 전체 본문은 `AGMO_CONTEXT_MODE=full`로 옵트인 (`hooks/session-start`, `scripts/wiki-context.sh`)
- `wiki-context.sh`에 `--manifest`/`--full` 모드 추가 — manifest는 페이지 제목·요약·카운트만 담은 ≤800자 지도를 출력하고 본문은 on-demand로 lazy 로드
- `using-plugin` 부트스트랩에 LLM Wiki lazy-loading 안내를 추가하고, Category Routing 상세 표를 `skills/using-plugin/references/category-routing.md`로 분리해 매 세션 eager 주입 토큰을 절감
- 스킬 카탈로그 카운트 28 → 29 (plugin.json / marketplace.json / README)

### Added
- `wiki-maintain` 스킬 신설 — llm-wiki 오염(모순·저신뢰·contested·superseded) 감지 시 호출 가능한 자가치유 워크플로우 (`skills/wiki-maintain/`)
- `AGMO_MANIFEST_HEALTH=1` 옵트인 — manifest 끝에 high-severity wiki 이슈 경고 한 줄 추가
- manifest/full 모드 회귀 테스트 (full byte-identical, manifest ≤800자, budget exit code)

### Rationale
- 매 세션 모든 컨텍스트를 eager 주입하던 방식을 "llm-wiki 존재만 인지시키고 필요할 때 lazy 로드"하는 모델로 전환해 세션시작 토큰 예산을 절감 (데이터 보유 프로젝트 기준 13,090자 → 8,893자, 약 4,197자 절감)
- 잘못된 지식베이스를 에이전트가 스스로 점검·수정할 수 있도록 `wiki-maintain`을 호출 가능한 스킬로 승격
- 하위호환: `AGMO_CONTEXT_MODE=full`로 기존 eager 동작을 보존하며, `--full` 출력은 이전과 byte-identical

## [0.8.0] - 2026-05-29

### Added
- llm-wiki project bootstrap workflow: `wiki-init.sh`, Obsidian-friendly project structure, schema/index/log templates, and setup skill integration
- session-start llm-wiki context budgeter: source-prioritized, deduplicated, budgeted project/shared context injection via `wiki-context.sh`
- wiki capture workflow: `wiki-capture.sh` for YAML-safe project/shared captures with confidence, supersession, and contested-context metadata
- wiki maintenance workflow: `wiki-maintain.sh` for stale, low-confidence, contested, superseded, broken wikilink, and missing-frontmatter detection
- regression tests for context budgeting, supersession filtering, and maintenance diagnostics

### Changed
- `session-start` now delegates llm-wiki context assembly to the reusable context script instead of ad-hoc shell logic
- plugin usage, setup, wisdom, vault-search, CLI reference, and save-impl documentation now describe the llm-wiki context hygiene loop

### Rationale
- Give long-running Claude Code workflows a local project memory layer that can be searched, curated, superseded, and kept clean instead of relying only on conversational memory
- Reduce stale-context contamination by making low-confidence/contested/superseded wiki entries visible and excluding superseded captures from startup context

## [0.7.2] - 2026-05-29

### Changed
- 모델 고정 에이전트 5종(planner / architect / critic / frontend / android-specialist)의 기본 모델을 `claude-opus-4-7` → `claude-opus-4-8`로 업그레이드

### Rationale
- Opus 4.8이 출시되어 동일 카테고리 슬롯에서 추론/코드 품질 개선을 기대
- executor / explore / archivist는 카테고리 라우팅(haiku·sonnet·opus) 그대로 유지 — 변경 없음

## [0.7.1] - 2026-04-17

### Changed
- 모델 고정 에이전트 5종(planner / architect / critic / frontend / android-specialist)의 기본 모델을 `claude-opus-4-6` → `claude-opus-4-7`로 업그레이드
- marketplace.json 버전 필드를 0.5.1 → 0.7.1 로 동기화 (이전 릴리즈들에서 누락되어 있었음)

### Rationale
- Opus 4.7이 안정화되어 동일 카테고리 슬롯에서 추론/코드 품질 개선을 기대
- executor / explore / archivist는 카테고리 라우팅(haiku·sonnet·opus) 그대로 유지 — 변경 없음

## [0.7.0] - 2026년 4월

### Added
- gstack 분석 기반 업그레이드 (PR #8, #9)
- guard 훅, wisdom 메타데이터, 신규 스킬
- README 배지 및 구조 재정비

## [0.6.1] - 이전

### Fixed
- Codex 호출 방식 전환: 슬래시 커맨드 → `codex:codex-rescue` 에이전트 디스패치

## [0.6.0] - 이전

### Added
- codex-plugin-cc 독립 검증자 통합 — 3개 품질 게이트에 Codex 삽입

## [0.5.1] - 이전

### Changed
- plugin-review 스킬 최적화 — 전체 유저 스코프 분석 + Python 파싱 스크립트

## [0.5.0] - 이전

### Added
- implement-page-android 스킬 및 android-specialist 에이전트 신규 구축
