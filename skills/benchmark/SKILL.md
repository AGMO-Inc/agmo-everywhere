---
name: benchmark
description: Use to run benchmarks, save results to Obsidian vault, and detect regressions against a baseline. Triggers on "벤치마크", "benchmark", "성능 측정".
---

# Benchmark — Execute, Save, Compare, Update Baseline

## Process

### Phase 1: Execute

Run the benchmark command specified by the user. Do not assume a specific framework — any shell command is valid (e.g., `hyperfine`, `go test -bench`, `pytest --benchmark`, custom scripts).

1. Ask the user for the benchmark command if not provided.
2. Run the command and capture full stdout/stderr output.
3. Extract numeric metrics from the output (e.g., ms, ops/sec, MB/s). Record each metric with its unit and label.

```
benchmark_output = run(user_command)
metrics = parse_numeric_results(benchmark_output)
# Example: { "p50_ms": 42.1, "p99_ms": 98.3, "throughput_rps": 5200 }
```

### Phase 2: Save

Delegate to `archivist` agent (haiku) to persist results to the Obsidian vault.

1. **Identify project** — `scripts/identify-project.sh` → PROJECT
2. **Resolve vault root** — read `AGMO_VAULT_ROOT` from environment or `scripts/identify-project.sh` output
3. **Determine date** — `date +%Y-%m-%d`
4. **Create tmpfile** — write to `/tmp/agmo-benchmark-{uuid}.md`:

```markdown
---
date: YYYY-MM-DD
project: {PROJECT}
command: "{benchmark command}"
type: benchmark
---

# Benchmark — YYYY-MM-DD

> Project: [[{PROJECT}]]

## Command

```
{benchmark command}
```

## Results

| Metric | Value |
|--------|-------|
| {metric_label} | {value} {unit} |
...

## Raw Output

```
{full benchmark output}
```
```

5. **Save** — write the file directly to:
   `{vault_root}/{PROJECT}/benchmarks/YYYY-MM-DD.md`
   (Use `scripts/vault-save.sh` if it supports `--path`, otherwise write directly with the Write tool.)
6. **Cleanup** — `rm /tmp/agmo-benchmark-{uuid}.md`

### Phase 3: Compare — Regression Detection

After saving, compare current results against the baseline.

1. **Locate baseline** — read `{vault_root}/{PROJECT}/benchmarks/baseline.md`
   - If baseline does not exist, skip comparison and notify the user. Suggest running update-baseline.
2. **Extract baseline metrics** — parse the same metric labels from baseline.md's Results table.
3. **Compute regression** — for each metric shared between current and baseline:

```
delta_pct = (current_value - baseline_value) / baseline_value * 100
```

   - For latency/time metrics: an **increase** is a regression.
   - For throughput/rate metrics: a **decrease** is a regression.

4. **Apply threshold** — if `abs(delta_pct) >= 10`, flag as regression warning.

```
REGRESSION DETECTED: {metric} degraded by {delta_pct:.1f}%
  baseline: {baseline_value} {unit}
  current:  {current_value} {unit}
  threshold: 10%
```

5. **Report** — print a comparison table:

```
## Regression Report

| Metric | Baseline | Current | Delta | Status |
|--------|----------|---------|-------|--------|
| p50_ms | 40.0 ms  | 42.1 ms | +5.3% | OK     |
| p99_ms | 80.0 ms  | 98.3 ms | +22.9% | ⚠ REGRESSION |
```

### Phase 4: Update Baseline

Baseline is **never updated automatically**. Update only when explicitly requested by the user (e.g., "베이스라인 갱신", "update baseline", "새 기준으로 설정").

When requested:

1. Confirm with the user: "현재 결과를 새 베이스라인으로 설정합니다. 계속하시겠습니까?"
2. On confirmation, overwrite `{vault_root}/{PROJECT}/benchmarks/baseline.md` with the same format as the current benchmark result, replacing the date header.
3. Notify: "baseline.md updated with results from YYYY-MM-DD."

## Vault Storage Format

- **Result files**: `{vault_root}/{PROJECT}/benchmarks/YYYY-MM-DD.md`
- **Baseline file**: `{vault_root}/{PROJECT}/benchmarks/baseline.md`

Both files use identical markdown structure so that the same parser applies to both.

## Regression Threshold

- Default threshold: **10%**
- Applies to all numeric metrics extracted from benchmark output.
- Direction sensitivity: latency higher = bad; throughput lower = bad. If direction cannot be determined from the metric label, treat any 10% change as a potential regression and warn.

## Constraints

- Do not bind to any specific benchmark framework. The user supplies the command.
- Do not auto-update the baseline under any circumstances. Explicit user request only.
- If the benchmark command fails (non-zero exit), report the error and abort — do not save partial results.
