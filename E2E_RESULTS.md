# End-to-end results

Tested on 2026-09-25 with OpenCode 2.0.15, an isolated snapshot of an
OpenAI OAuth account, `openai/gpt-5.6-luna-fast` as the coding agent, and
`openai/gpt-5.5-fast` as the permission evaluator.

The project configuration contained no explicit `permissions` rules.

| Agent-issued operation | Initial effect | Final effect | Decision path | Observed result |
| --- | --- | --- | --- | --- |
| `shell: pwd` | `allow` | `allow` | Evaluator model, 3.3s | Executed and returned `/workspace/fixture`. |
| `edit: safe-zone/new-note.txt` | `allow` | `ask` | Deterministic human-edit policy, 0ms | Permission requested; non-interactive client rejected it and no file was created. |
| `shell: rm -rf generated` | `allow` | `ask` | Evaluator model, 3.6s | Permission requested; non-interactive client rejected it and the command did not execute. |

The edit result demonstrates the core invariant: the evaluator model is not
called for OpenCode's `edit` permission action, which covers edit, write, and
patch tools.

Additional verification:

- The copied OAuth database authenticated successfully from the container.
- The live host database and host OpenCode configuration were not mounted.
- `openai/gpt-5.3-codex-spark` was rejected by this ChatGPT OAuth account;
  `openai/gpt-5.5-fast` was verified and selected instead.
- The Docker image built successfully with the matching
  `@opencode/plugin@2.0.15` package.
- Unit tests, strict TypeScript checks, plugin bundling, and shell syntax checks
  passed.
- No sandbox test containers remained running after the checks.
