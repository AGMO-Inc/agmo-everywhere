# GitHub Issue Templates (SSOT: AGMO-Inc/.github)

Source: https://github.com/AGMO-Inc/.github/tree/main/.github/ISSUE_TEMPLATE

## Template Verification
```bash
gh api "repos/AGMO-Inc/.github/contents/.github/ISSUE_TEMPLATE?ref=main"
```

## Feature (`01-기능-개발.yml`)

- Title: `[Feature] 이슈 한줄 요약을 제목으로`
- Type: Feature
- Required sections: 1. 한 줄 요약, 2. 배경/문제, 3. 요구 사항, 4. 작업 항목
- Optional sections: 5. 참고, 6. 수용 기준, 7. 상태 모델, 8. API/프로토콜, 9. 데이터 모델, 10. 비기능 요구사항

## Task (`02-기능-개발---하위-태스크.yml`)

- Title: `[Task] {상위 기능 제목} - 하위 태스크 요약`
- Type: Task
- Required sections: 상위 Feature (이슈 번호), 1. 작업 요약, 2. 체크리스트
- Optional sections: 3. 참고, 4. 상세 수용 기준, 5. 검증 로그/링크

## Bug (`03-버그-리포트.yml`)

- Title: `[Bug] 문제가 요약된 제목`
- Type: Bug
- Required sections: 1. 증상 한 줄 요약, 2. 기대 동작, 3. 실제 동작, 5. 빈도, 6. 사용자 영향, 7. 해결 방법
- Optional sections: 4. 재현 방법
