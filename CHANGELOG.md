# Changelog

All notable changes to the agmo Claude Code plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
