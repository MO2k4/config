# CLAUDE Configuration

## Context Efficiency

Think about context efficiency before running commands. Use filters and output-limiting tools such as `head` and `tail` to keep output focused on relevant information. Be careful with unfamiliar commands that may produce verbose output, and check their options or redirect their output before running them without limits.

But don't overdo it:

- Don't put a lot of bash commands into a single tool call if it doesn't provide benefits for efficiency. Multiple bash calls for independent operations can be easier to understand to the user.
- Prefer the codemode tool for composing over bash, as it also helps with readability and transparency. You can still use bash commands during codemode.
- Then using the codemode tool, don't make the code too dense and use whitespace for better readability

## Comments

Do not over-comment. A comment must earn its line; the default is no comment.

- **Explain why, not what.** The code already says what it does. Comment the reason: the tradeoff, the constraint, the bug being worked around, the non-obvious business rule.
- **Prefer clearer code over a comment.** If a comment explains a block, extract a well-named function or variable instead. A comment is a failure to express it in code — sometimes unavoidable, never the first move.
- **Never restate the code.** No `// increment i`, no narrating the obvious, no comment on every line or every field.
- **No history.** Comments describe the code as it is now, not how it got here. No changelogs, dates, author tags, "changed from X", "previously did Y", "added for ticket Z", "removed in v2" — git blame and the PR hold that. The one exception: when a past decision still constrains the present, state the constraint, not the history ("keep the retry at 3 — the upstream gateway drops on the 4th" beats "bumped from 5 to 3 in Jan").
- **No ceremony.** No banner/section dividers, no commented-out code, no "TODO: maybe later" without a concrete reason.
- **Do comment:** workarounds (name the upstream bug/version), non-obvious performance choices, unit/format/invariant assumptions, and deliberate deviations from the surrounding pattern.
- **Match the file.** Follow the comment density and style already in the code you're editing.
- **Public API docstrings are documentation, not comments** — keep them where the language's conventions expect them, and keep them short.
- **Stale beats missing is false.** If a change makes a comment wrong, fix or delete it in the same diff.

## Subagents and scratch files

- Subagents that fix code stop at the commit. The main session does `git push`, `gh pr create` and every other GitHub write. Keep spawn prompts self-contained: inline the steps instead of "follow <brief>.md exactly", and don't write "the user allowed X" into a prompt. The auto-mode classifier blocks such spawns.
- Write logs and scratch files to the repo's gitignored `.local/`, not `/tmp`. context-mode refuses to read files outside the project.
