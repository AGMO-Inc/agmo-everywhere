# Implementation Note Template

Sections can be adjusted based on implementation. Below is the recommended structure.

```markdown
---
type: impl
project: {PROJECT}
issue: "{ISSUE_NUM}"
pr: "{PR_NUMBER}"
plan: "[[{PROJECT}/plans/[Plan] {PLAN_TITLE}]]"
status: done
created: {YYYY-MM-DD}
tags:
  - impl
  - {PROJECT}
---

# {구현 제목}

> 플랜: [[{PROJECT}/plans/[Plan] {PLAN_TITLE}]]

## 구현 요약

{핵심 구현 내용 — 무엇을 왜 구현했는지}

## 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `파일명` | 설명 |

## 핵심 구현 사항

{주요 로직, 알고리즘, 패턴 등 구현 세부사항}

## 설계 결정

{구현 중 내린 결정사항과 근거}

## API 엔드포인트

{새로 추가된 API가 있을 때만 포함}

| 메서드 | URL | 설명 |
|--------|-----|------|
| GET | `/path` | 설명 |

## 검증 결과

{빌드/테스트 실행 결과}

---
> GitHub Issue: [#{ISSUE_NUM}](https://github.com/{OWNER}/{PROJECT}/issues/{ISSUE_NUM})
> PR: [PR #{PR_NUMBER}]({PR_URL})
> 브랜치: `{BRANCH}`
```

## Section Guide

| Section | Required | Description |
|---------|----------|-------------|
| Implementation Summary | O | 2-3 lines of key content |
| Changed Files | O | Table format recommended |
| Key Implementation Details | O | Key logic/patterns |
| Design Decisions | △ | When non-obvious decisions exist |
| API Endpoints | △ | Only when API changes exist |
| Verification Results | △ | Build/test results |

△ = Include only when applicable. Omit unnecessary empty sections.
