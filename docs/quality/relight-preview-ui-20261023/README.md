# Relight real-preview confirmation regression — 2026-10-23

The existing RelightFlow coordinator now supplies shared TuneChatStep and PlanDeckStep with real preview generation/restoration, cancellation, current request identity, before-photo comparison, and manual photo-region selection.

- Old-space data and original plan restore before mounting direct-link tune. Its first round uses the persisted original goal.
- Every preference enters the shared real image request; a new preference invalidates the old image. Only the current loaded image enables “确认效果图，继续整理”. Text-only continuation is explicitly labelled.
- Scope changes, refining, backing out, and unmounting invalidate pending results and call native cancellation.
- Restoration/generation verifies the selected space matches this Relight space before bridge calls and before displaying responses.
- Uploads and provider consent continue through existing native image.preview.generate.

Validation: Vite production build succeeds. Existing tunePlan/imagePreview unit tests: 4/4 pass. New relight-preview-ui-smoke.mjs: 10/10 checks across 390px and 320px, errors=[]. Fixture includes an active original plan and asserts its summary survives in the preview goal. 320px screenshot visually inspected.

Environment: Desktop Chromium; synthetic SVG before/after images; native bridge fixture. No provider request, paid generation, iPhone, or private photo. These results verify UI/request behavior, not generated-image fidelity or native consent/network behavior. The initial missing-import failure was fixed; its screenshot remains in ignored outputs/relight-preview-ui-20261023/initial-missing-import.png.

Native caveat: the bridge derives its image from selectedBeforeImage(). Frontend checks prevent ordinary wrong-space calls and discard changed-space results. An independent native space change during asynchronous upload consent would require an expected-space guard in the native handler for an absolute invariant. This task did not edit native code.
