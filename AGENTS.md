# Repository Guidelines

## Project Structure & Module Organization
This repository is currently bootstrapped and contains only top-level docs (`README.md` and this file).
Keep the root directory clean and add code in dedicated folders as the project grows:
- `src/` for application code
- `tests/` for automated tests (mirror `src/` paths)
- `docs/` for architecture/design notes
- `assets/` for static files

Prefer small, single-purpose modules and keep related helpers near the feature they support.

## Build, Test, and Development Commands
No build system or test runner is committed yet. Until tooling is added, use these baseline commands:
- `rg --files` to quickly inspect tracked files
- `git status` to verify working tree state
- `git diff --stat` to review change scope before committing

When build/test tooling is introduced, document canonical commands in `README.md` and keep this guide aligned.

## Coding Style & Naming Conventions
Use clear, readable Markdown and keep lines reasonably short (around 100 chars).
Adopt consistent naming:
- directories: lowercase kebab-case (`markdown-parser/`)
- files/types/functions: follow the conventions of the selected language

Keep functions focused, avoid large multi-purpose files, and run the language formatter/linter before opening a PR.

## Testing Guidelines
Automated tests are not configured yet. For any new executable code:
- add tests under `tests/` with mirrored structure
- include at least one happy-path and one failure-path case
- document test commands in `README.md` once a framework is selected

## Commit & Pull Request Guidelines
The repository has no commit history yet; start with Conventional Commits:
- `feat: add markdown preview parser scaffold`
- `fix: handle empty markdown input`

Keep commits atomic and focused. PRs should include:
- what changed and why
- how it was verified (commands/output)
- linked issue(s), if applicable
- screenshots or terminal output for user-facing behavior changes

## Security & Configuration Tips
Do not commit secrets, tokens, or local config with credentials.
When configuration is introduced, document required environment variables in `README.md`.
