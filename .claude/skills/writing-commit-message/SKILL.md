---
name: writing-commit-message
description: Use when the user asks to write or generate a git commit message for the bf_playground project (Flutter Web Brainfuck live-preview app)
---

# Git Commit Message Specification

## Title Format

```
<type>(<scope>): <English summary>
```

- **type**: `feat` | `fix` | `perf` | `refactor` | `docs` | `test`
- **scope**: one scope per module, matching the changed component:
  - `app` - application entry and root widget (`lib/main.dart`).
  - `controller` - the VmController session core: Stepper ownership, play/pause Timer, input queue, output buffer, pending/error state, and the app-side `BrainfuckIO` implementation (`lib/vm_controller.dart`).
  - `codeview` - the code editor box: in-editor pc highlight via `Program.sourceOffsets` (custom `TextEditingController.buildTextSpan`), and the read-only instruction strip.
  - `tapeview` - the tape grid visualization: pointer highlighting, follow scrolling, value-change flash.
  - `ui` - page layout, operator keypad, control area (step/play/reset/speed), input/output boxes.
  - `build` - package config, lint, tooling, and dependencies (`pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`, `.claude/`, `.github/`).
  - `docs` - project documentation (`README.md` and other tracked docs).
- **summary**: One sentence describing what was done, starting with a verb, in English.

Test files take the scope of the module under test (usually with type `test`).
When a change spans multiple modules, pick the scope of the most significant changed file.

Examples:
- `feat(controller): auto-execute appended operators while pc sits at program end`
- `fix(tapeview): keep the pointer cell visible during follow scrolling`
- `feat(codeview): highlight the current instruction via Program.sourceOffsets`
- `docs: document local run steps in README`

## Body Structure

The body is organized into the following paragraphs, each beginning with a bold label:

### Feature/Fix Description (first paragraph)

Briefly explain the purpose and core changes of this commit, in 2–4 sentences.

### Engineering Changes

Starts with **Engineering Changes:**, lists all added/modified/deleted files with specific changes:

```
Engineering Changes:
- Added lib/vm_controller.dart: VmController holds the Stepper session,
  input queue, output buffer, and pending state; dispatches code-box
  onChanged events into append-execute, pending, and reset branches
- Modified lib/main.dart: wire the root widget to an AnimatedBuilder
  listening to the VmController
```

### Tests

Starts with **Tests:**, describing test results:

```
Tests:
- Added test/vm_controller_test.dart: covers instant execution on append,
  pending buffering until brackets balance, and session reset on mid-program edits
- flutter test: all tests pass; flutter analyze: no issues; dart format --set-exit-if-changed --output=none .: clean
```

For documentation-only changes:
```
Tests:
- Documentation-only change, no code tests run
```

### Documentation

Starts with **Documentation:**, listing updated doc files. If no tracked documentation changed, write `- None`.

**Exclusion rule**: Changes under `docs/superpowers/` and `CLAUDE.md` never appear in commit messages — they are untracked via `.gitignore` (design notes and local instructions, not project files).

```
Documentation:
- Updated README.md: added the local run steps and a layout screenshot
```

## Full Example

```
feat(controller): auto-execute appended operators while pc sits at program end

Appending operators at the end of the code box now executes them
immediately with step animation whenever the session pc sits at the
previous program end, giving the REPL-like instant feedback from the
design spec. Appends that leave brackets unbalanced enter a pending
state instead, and edits anywhere else reset the session with a toast.

Engineering Changes:
- Added lib/vm_controller.dart: VmController holds the Stepper session,
  play Timer, input queue, output buffer, and pending state; dispatches
  code-box onChanged events into append-execute, pending, and reset branches
- Modified lib/main.dart: wire the root widget to an AnimatedBuilder
  listening to the VmController

Tests:
- Added test/vm_controller_test.dart: covers instant execution on append,
  pending buffering until brackets balance, and session reset on mid-program edits
- flutter test: all tests pass; flutter analyze: no issues; dart format --set-exit-if-changed --output=none .: clean

Documentation:
- None
```

## Complete Workflow (Mandatory)

Before writing the commit message, you must follow this sequence:

### 1. Read project documentation for context

Read the project documentation to understand the current structure and conventions:

- `CLAUDE.md` (if present) - project architecture, build/test/lint commands, code style
- `README.md` - features and usage
- `docs/superpowers/specs/` - the design spec defining the §5 components (execution model, UI layout); use it to understand what each module is for (these files are design notes and must never be mentioned in the commit message itself)

### 2. Review recent commits as reference

```bash
git log -3 --format="%H%n%s%n%b%n---"   # last 3 full commits
```

Refer to historical type selection, summary style, and body structure. Choose the scope from the project's modules (see the scope list above), not from past commit subjects. If the repository has no commits yet, skip this step and follow this specification directly.

### 3. Determine the scope of changes with git status and git diff

```bash
git status --short            # untracked + modified files (untracked files never show in git diff)
git diff --name-only          # working tree changes
git diff --cached --name-only # staged changes
```

Classify changed files by module to choose the scope: `app` (`lib/main.dart`), `controller` (VmController / session / `BrainfuckIO` implementation), `codeview` (code box, in-editor highlight, instruction strip), `tapeview` (tape grid), `ui` (layout, keypad, controls, input/output boxes), `build` (`pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`, `.claude/`, `.github/`), `docs` (`README.md` and other tracked docs). Test files take the scope of the module under test.

### 4. Analyze the role of the changes in the project

- Determine change type: feat / fix / perf / refactor / docs / test
- Determine scope from the changed component (see the scope list above); when multiple modules change, use the most significant one.
- Understand its position and role in the overall project architecture (which module, what problem it solves, what improvement it brings)

### 5. Generate commit message

Based on the analysis above, generate the commit message according to this specification.

## Output Method (Mandatory)

After generating the commit message, you **must** write it to the `.tmp/commit_message.md` file, **overwriting** (not appending).

Process:
1. `mkdir -p .tmp` (ensure directory exists)
2. Use Write tool to write the full commit message into `.tmp/commit_message.md` (overwrite each time)

**Prohibited**: Do not output the commit message in the terminal, do not invoke `git commit` directly. Only write the file.

The user will review `.tmp/commit_message.md` and commit manually.

## Prohibited Actions

- Do not run `git add` or `git commit` on your own; the commit must be reviewed by the user.
- Do not use non-English in the title (except type/scope).
- Do not omit the body structure paragraph labels.
