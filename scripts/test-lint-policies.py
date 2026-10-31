#!/usr/bin/env python3
"""Exercise native engines with valid documents and targeted policy mutations.

No YAML loader or policy engine is implemented here: JSON is valid YAML, and
kongctl/decK evaluate every case. Negative cases must identify the intended rule.
"""
import copy
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
suite = json.loads((root / "lint/fixtures.json").read_text())
count = 0
with tempfile.TemporaryDirectory(prefix="kongairlines-lint-") as temporary:
    for group in suite:
        for case in [{"name": "valid"}, *group["cases"]]:
            document = copy.deepcopy(group["document"])
            for change in case.get("changes", []):
                parent = document
                for key in change["path"][:-1]:
                    parent = parent[key]
                key = change["path"][-1]
                if change.get("delete"):
                    del parent[key]
                else:
                    parent[key] = change["value"]
            source = Path(temporary) / "input.yaml"
            source.write_text(json.dumps(document))
            if group["tool"] == "kongctl":
                command = ["kongctl", "lint", "-f", str(source), "-r", group["rules"], "--output", "json", "--fail-severity", "error"]
            else:
                command = ["deck", "file", "lint", "--state", str(source), group["rules"], "--format", "json", "--analytics=false"]
            result = subprocess.run(command, cwd=root, text=True, capture_output=True)
            try:
                report = json.loads(result.stdout)
            except ValueError as error:
                raise SystemExit(f"{group['rules']} {case['name']}: invalid lint output: {result.stdout} {result.stderr}") from error
            expected = case.get("rule")
            if expected:
                # decK omits rule IDs from JSON; descriptions include the stable ID.
                diagnostics = json.dumps(report.get("results", []))
                assert result.returncode != 0 and report.get("fail_count", 0) > 0 and expected in diagnostics, (group["rules"], case, result.stdout, result.stderr)
            else:
                assert result.returncode == 0 and report.get("total_count") == 0, (group["rules"], case, result.stdout, result.stderr)
            count += 1
print(f"Passed {count} native lint regression cases")
