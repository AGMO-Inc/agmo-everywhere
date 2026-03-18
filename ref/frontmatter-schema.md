# Frontmatter Schema

## Plan Note

```yaml
---
type: plan
project: {PROJECT}
issue: null
issue-type: feature | task | bug
status: draft | issued | in-progress | done
created: YYYY-MM-DD
tags:
  - plan
  - {PROJECT}
---
```

## Implementation Note

```yaml
---
type: impl
project: {PROJECT}
issue: "#number"
pr: "#number"
plan: "[[{PROJECT}/plans/[Plan] title]]"
status: in-progress | done
created: YYYY-MM-DD
tags:
  - impl
  - {PROJECT}
---
```

## Design Note

```yaml
---
type: design
project: {PROJECT}
status: draft | review | done
created: YYYY-MM-DD
tags:
  - design
  - {PROJECT}
---
```

## Research Note

```yaml
---
type: research
project: {PROJECT}
status: draft | done
created: YYYY-MM-DD
tags:
  - research
  - {PROJECT}
---
```

## Meeting Note

```yaml
---
type: meeting
project: {PROJECT}
date: YYYY-MM-DD
attendees: []
created: YYYY-MM-DD
tags:
  - meeting
  - {PROJECT}
---
```

## Memo Note

```yaml
---
type: memo
project: {PROJECT}
created: YYYY-MM-DD
tags:
  - memo
  - {PROJECT}
---
```

## Project Index Note

```yaml
---
type: project-index
project: {PROJECT}
repo: {OWNER}/{PROJECT}
project-url: https://github.com/orgs/{OWNER}/projects/{N}
tags:
  - project
---
```
