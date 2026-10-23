# Project context — docksnap (DockSnap)

- GitHub: https://github.com/quyansiyuanwang/docksnap
- Product: `DockSnap` — a macOS menu bar utility that saves and restores window
  frames, aligning the left edge with the Dock (SwiftPM only, no Xcode project).
- **Owner username: `quyansiyuanwang`.** Use it in every URL, badge, and
  `Package.swift` example. Never write `<owner>` or any other placeholder.
- Zero third-party dependencies. Window manipulation uses the Accessibility API
  (`AXUIElement`); global hot keys use Carbon's `RegisterEventHotKey`.
- Coordinates use the Accessibility API space (top-left origin, y downwards).
  Conversions from Cocoa live in `Screens.swift`.
- Swift 6 strict concurrency, zero warnings. Validate with
  `swift build -Xswiftc -warnings-as-errors` and
  `swift test -Xswiftc -warnings-as-errors`.
- Tests use Swift Testing (`@Suite` / `@Test` / `#expect`).
- Bundle with `./build.sh`. The app is signed with the local identity
  `DockSnap Local Signing` (see `scripts/create-signing-identity.sh`) so the
  Accessibility permission is not lost on rebuilds.
- Docs: professional/technical tone, no emoji, no colloquialisms. The README,
  CHANGELOG and CONTRIBUTING files are bilingual: an English original
  (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`) and a `*.zh-CN.md` translation,
  each linking to the other. Keep them in sync when behaviour changes. Other
  docs stay in English.
- `CHANGELOG.md` and `CHANGELOG.zh-CN.md` are generated at release time by
  `scripts/changelog.py` from the conventional commits between two tags; never
  edit them by hand. The release workflow writes both files, commits them to
  `main`, and publishes the GitHub release notes from the same data. Commit
  prefixes therefore matter: `feat:`, `fix:` and `perf:`/`refactor:` map to
  *Added*, *Fixed* and *Changed*; `docs:`, `ci:`, `build:`, `test:`, `style:`
  and `chore:` produce no entry unless the change is user-visible.
