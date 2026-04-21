# App Development Model Guide

This document captures a practical model and speed setup for building applications with ChatGPT Plus and Codex.

## Recommended Working Pattern

- Use `GPT-5.4` for feature design, system architecture, debugging unclear failures, schema decisions, prompt design, UX copy, and "why is this not working?" sessions.
- Use `GPT-5.3-Codex` for repetitive component building, boilerplate expansion, test writing, mechanical refactors, and multi-file code edits.
- Use `Fast` only when you are actively driving a tight feedback loop and want responsiveness more than efficiency.

`Fast` mode is best treated as a selective acceleration tool rather than a default setting, since it consumes usage at `2x` the standard rate.

## Plus Setup For App Development

- Use `GPT-5.4` as the default thinking model.
- Stay on `Standard` speed almost all the time.
- Switch to `GPT-5.3-Codex` when you are doing long stretches of implementation work.
- Minimize cloud tasks unless they clearly save time.
- Break work into smaller feature slices instead of making giant "build the whole app" requests.

## Practical Default

For most app-development sessions, the best default is:

- Model: `GPT-5.4`
- Speed: `Standard`
- Secondary implementation model: `GPT-5.3-Codex`

This setup gives better balance across planning, architecture, coding, debugging, and product iteration than using a coding-specialized model for everything.
