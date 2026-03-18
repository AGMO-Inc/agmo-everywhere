# Link Strategy

## Internal Links (wikilink)

| Link | Format | Example |
|------|--------|---------|
| Note → Project Index | `[[{project}]]` | `[[agmo-agent]]` |
| Impl → Plan | `[[{project}/plans/[Plan] title]]` | `[[agmo-agent/plans/[Plan] 소유권 변경]]` |
| Plan ← Impl backlink | append | `- Impl: [[{project}/implementations/[Impl] title]]` |

## External Links (GitHub)

| Target | Format |
|--------|--------|
| Issue | `[#42](https://github.com/{OWNER}/{PROJECT}/issues/42)` |
| PR | `[PR #45](https://github.com/{OWNER}/{PROJECT}/pull/45)` |

## Project Index Hub

All Plan/Impl notes link to `[[{project}]]`, so the index note's backlink panel shows everything at a glance.
