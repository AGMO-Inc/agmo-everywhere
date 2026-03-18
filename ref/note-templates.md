# 노트 타입별 템플릿

## Design 노트

```markdown
---
type: design
project: {PROJECT}
status: draft | review | done
created: {YYYY-MM-DD}
tags:
  - design
  - {PROJECT}
---

# {제목}

> 프로젝트: [[{PROJECT}]]

## 개요

{설계 배경 및 목적}

## 상세 내용

{설계 내용, 요구사항 분석, 브레인스토밍 결과 등}

## 결정 사항

{확정된 사항 정리}

## 참고

{관련 링크, 원본 파일 등}
```

## Research 노트

```markdown
---
type: research
project: {PROJECT}
status: draft | done
created: {YYYY-MM-DD}
tags:
  - research
  - {PROJECT}
---

# {제목}

> 프로젝트: [[{PROJECT}]]

## 배경

{조사 목적 및 배경}

## 조사 내용

{기술 조사, 비교 분석, PoC 결과 등}

## 결론 및 권장사항

{조사 결과 요약 및 추천}

## 참고

{참고 문서, URL 등}
```

## Meeting 노트

```markdown
---
type: meeting
project: {PROJECT}
date: {YYYY-MM-DD}
attendees: []
created: {YYYY-MM-DD}
tags:
  - meeting
  - {PROJECT}
---

# {제목}

> 프로젝트: [[{PROJECT}]]

## 안건

{회의 안건}

## 논의 내용

{주요 논의사항}

## 결정 사항

{확정된 결정}

## Action Items

- [ ] {할 일}
```

## Memo 노트

```markdown
---
type: memo
project: {PROJECT}
created: {YYYY-MM-DD}
tags:
  - memo
  - {PROJECT}
---

# {제목}

> 프로젝트: [[{PROJECT}]]

{자유 형식 내용}
```
