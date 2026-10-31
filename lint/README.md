# Native configuration policy

Run from the repository root with latest stable kongctl, decK 1.65.2, Python 3
and Ruby (release consistency validation):

```sh
python3 scripts/test-lint-policies.py
python3 scripts/test-release-consistency.py
./scripts/lint-reference-platform.sh
deck file validate gateway/dev/kong.yaml
deck file validate gateway/prod/kong.yaml
```

`kongctl lint` checks the current OpenAPI contract and raw development/production
Catalog manifests. `deck file lint` checks every generated entity's ownership,
source reconciliation selectors and authentication policy. The shared Gateway
rules are inherited by the environment rulesets. Rules are local and versioned;
no credentials or live lookups are required. Schema validation remains separate.

Lint does not expand `!file`, `!ref` or `!lookup` (kongctl issue #2584). Referenced
OpenAPI input is linted directly; the release validator checks file consistency
and Git history. Historical release contracts are preserved, not subjected to
the current beta/health-path policy. Runtime identity tests remain separate.

The JSON fixtures are valid YAML input for both native engines. Negative cases
assert the intended rule diagnostic, including absent fields and nested tags.
This guards against selectors silently matching nothing; malformed JSONPath
error reporting is tracked in https://github.com/Kong/kongctl/issues/2653.
Keep fixture coverage when editing rules or upgrading tools.
