# Guardians of the Diff

> Automate the routine. Guard the diff.

Guardians of the Diff is an [OpenCode](https://opencode.ai/) permission plugin
that lets a small model evaluate routine tool calls while preserving one simple
boundary: **every code edit requires a human decision**.

```text
tool permission
├── edit / write / patch ──> ask the human
└── everything else ───────> evaluator model ──> allow or ask
                                      failure ──> ask
```

OpenCode represents its `edit`, `write`, and `patch` tools with the `edit`
permission action, so they all take the deterministic human path. The evaluator
never gets an opportunity to auto-approve them.

## Why

Blanket auto-approval is fast but removes meaningful control. Prompting for
every read, search, and routine shell command is safe but exhausting.

Guardians of the Diff keeps the useful middle:

- Low-risk, clearly requested operations can proceed automatically.
- Ambiguous or consequential operations are escalated.
- Code changes always remain human-owned.
- Evaluator timeouts, malformed responses, and provider failures fail closed to
  `ask`, not `allow`.

This is a convenience and oversight layer, not a sandbox. Deterministic OpenCode
permission rules should still deny operations that must never run.

## Install

Install directly from GitHub:

```bash
opencode plugin add github:bhargav50/guardians-of-the-diff
```

Or add the package to `opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    {
      "package": "github:bhargav50/guardians-of-the-diff",
      "options": {
        "model": "openai/gpt-5.5-fast",
        "timeoutMs": 20000
      }
    }
  ]
}
```

The evaluator model must already be available to OpenCode. Any
`provider/model` may be configured.

Keep the terminal client in prompt mode so escalated decisions reach you:

```jsonc
// ~/.config/opencode/cli.json
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "session": {
    "permissions": "prompt"
  }
}
```

## Configuration

Plugin options are preferred; environment variables are useful for isolated
servers and containers.

| Option | Environment variable | Default | Purpose |
| --- | --- | --- | --- |
| `model` | `OPENCODE_EVALUATOR_MODEL` | `openai/gpt-5.5-fast` | Small model used for non-edit decisions. |
| `timeoutMs` | `OPENCODE_EVALUATOR_TIMEOUT_MS` | `20000` | Evaluator deadline, from 1–120 seconds. |
| `auditPath` | `OPENCODE_PERMISSION_AUDIT` | disabled | Optional JSONL decision log. |

Audit records contain action resources such as commands and paths. Do not enable
auditing where those values may contain secrets unless the destination and
retention policy are appropriate.

## Decision order

1. OpenCode evaluates configured permissions.
2. A configured `deny` remains final and never reaches the plugin.
3. The plugin receives initial `allow` and `ask` decisions.
4. `edit` is immediately changed to `ask` without an evaluator call.
5. Other actions are classified as `allow` or `ask` by the configured model.
6. Any evaluator failure becomes `ask`.

The plugin intentionally never emits `deny`. Use ordinary OpenCode permissions
or hard policies for deterministic denials.

## Development

```bash
bun install
bun run check
```

The policy is isolated in `src/policy.ts`; OpenCode integration stays in
`src/index.ts`. Unit tests focus on the invariant that edits cannot enter the
automatic evaluator path.

## Disposable end-to-end sandbox

The repository includes a Docker fixture that starts a real OpenCode 2.0.15
session without mounting host configuration or source code.

```bash
./build.sh
./run.sh /absolute/path/to/a-consistent-opencode-db-snapshot
```

Never mount the live OpenCode SQLite database. The launcher mounts a snapshot
read-only and copies it inside the disposable container so OAuth refreshes and
session writes cannot mutate host state. Suggested exercises are in
`fixture-seed/EXERCISES.md`.

## License

MIT
