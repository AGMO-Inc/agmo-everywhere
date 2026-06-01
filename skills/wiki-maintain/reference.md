# Wiki Maintain — Issue Kind Reference

## Issue Kind × Remediation Action

| Kind | Severity | 의미 | 권장 조치 |
|------|----------|------|-----------|
| `STALE` | medium | 마지막 업데이트로부터 `--max-age-days`(기본 90일)가 경과. 내용이 코드/현실과 달라졌을 수 있음. | 내용 검토 후 여전히 유효하면 `updated` 날짜 갱신(recapture). 사실 변경이 확인되면 supersede. |
| `LOW_CONFIDENCE` | high | frontmatter에 `confidence: low`로 표시된 페이지. 검증되지 않은 가설이거나 추측. | 코드·현실과 대조하여 검증. 사실이면 `confidence: high`로 supersede. 거짓이면 supersede(정정본) 또는 삭제 후 새 capture. 판단 불가 시 contest. |
| `CONTESTED` | high | frontmatter에 `contested: true` 또는 `contradictions` 필드가 있음. 상충하는 정보가 존재함. | 모순을 코드·사용자 확인으로 reconcile. 해결되면 정본으로 supersede, 이전 페이지는 자동으로 SUPERSEDED 처리됨. 미해결 시 contest 상태 유지(강제 해결 금지). |
| `SUPERSEDED` | medium | 다른 페이지의 `supersedes` 필드가 이 페이지를 참조함. 이미 대체된 구버전 내용. | 이 페이지를 컨텍스트 주입 대상에서 제외. LLM이 직접 의존하지 않도록 주의. 명시적 정리가 필요하면 사용자 승인 후 삭제 또는 아카이브. |
| `MISSING_FRONTMATTER` | medium | 페이지 상단에 YAML frontmatter(`---` 블록)가 없음. 메타데이터(confidence, updated, type 등) 추적 불가. | `wiki-capture.sh`로 re-capture하여 frontmatter를 포함한 새 파일을 생성(supersede 방식). 또는 파일 직접 편집으로 `---` 블록 추가(recapture). |
| `BROKEN_WIKILINK` | low | 페이지 본문의 `[[wikilink]]`가 존재하지 않는 파일을 참조함. | 링크 대상 파일이 이동·삭제된 경우 링크를 수정하거나 제거. 대상이 새로 필요한 페이지라면 새 capture 후 링크 유지. |

## Notes

- `supersede` 조치는 항상 `wiki-capture.sh --supersedes <old-path>`로 수행하며, 구 페이지는 자동으로 SUPERSEDED 이슈로 표시됨.
- `contest` 조치는 모순이 명확하나 진실을 특정할 수 없을 때만 사용. 모순이 해소되는 즉시 supersede로 전환.
- STALE, SUPERSEDED, MISSING_FRONTMATTER는 medium severity이므로 high severity 이슈 처리 후 순차 처리.
