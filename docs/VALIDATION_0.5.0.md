# SQLGarden 0.5.0 preview — Validation

## Executed

- `swift build`: passed using Apple Swift 6.4.2 and Xcode on the local Apple Silicon Mac.
- `bash scripts/test.sh`: all 15 simulated-driver C bridge tests and 23 StudioCore tests passed.
- `bash scripts/test-ui.sh` without integration credentials: 23 offline checks passed, including three new cases for document-owned result selection and clamping after result changes.
- Offline SwiftUI/AppKit snapshots inspected in light/dark at 1280×820 and at the 920×620 minimum layout. The test executable does not load the packaged asset catalog; branding was separately checked in the built app.
- `bash scripts/build-app.sh release universal`: arm64 and x86_64 binaries compiled, asset catalog processed, and ad hoc signing verified.
- Opened a QA copy with bundle identifier `app.sqlgarden.preview050`, isolating recovery and defaults from the installed application.
- In the actual QA window: hid results with the toolbar, restored them with Shift-Command-R, created another query with Command-N, and switched back to the first document. AX state confirmed the active document and result visibility transitions. The integrated adaptive logo was visually inspected.

## Not executed

No live SQL Server queries, cancellation/transaction regressions, database mutations, or new integration-server provisioning were performed. Existing driver/core tests are not a substitute for real-server validation. No physical Intel/macOS-14/clean-Mac test, full VoiceOver audit, performance benchmark, or notarization was performed. The installed SQLGarden app was not replaced.

## Asset preparation

The approved icon raster was cropped to its tile, placed in a transparent native icon canvas, and exported at the existing catalog's 1x/2x sizes and as ICNS. The approved wordmark was prepared with imagegen as a transparent raster and is rendered as a semantic template to remain visible on light and dark backgrounds. It remains raster artwork, not a new vector master. The legacy icon workflow was retained for the supported macOS baseline; this is not an Icon Composer layered project.

## Shipping status

Preview build for review, not a claim of full production qualification. Prior tags are immutable. Sources, design decisions and validation are included for review.
