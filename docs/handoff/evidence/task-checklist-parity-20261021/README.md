# Task Checklist Smoke · 2026-10-21

- `00-task-checklist.png` is the latest 390 × 844 production-dist screenshot using a fixture plan with three real destination groups.
- `result.json` records the latest production-dist Playwright run with a simulated native bridge.
- The smoke verifies inactive-group tasks are disabled and emit no completion request before checking that the active native UUID can still advance.
- `native-launch-space.png` is a fresh Debug app launch on iPhone 16 Pro / iOS 18.5 Simulator after rebuilding the embedded web asset. It shows the space map only; TaskStep was not opened in the native app.
- The fixture zones are storage destinations, not Figma's tabletop/under-desk physical regions. This evidence checks current display and step-save guards only; it does not prove physical-zone parity, Swift persistence, or simulator installation.
- Figma source references and unresolved mapping are documented in `docs/design/task-checklist-parity-20261021.md`.
