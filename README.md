# music-life

iOS/Android Music App

Review code as a senior eng. Ignore style. Focus on architecture, logic, security, perf.
Extract top 3 critical issues. Scope tasks independently to minimize merge conflicts (no overlapping files).
Directly EXECUTE 3 `gh issue create` commands via your terminal/shell tool. No conversational text.
Format:
gh issue create --title "[Category]: Summary" --body "Problem: [Detail]
Location: [File/Func]
Fix: [Snippet]" --label "bug" --assignee "@Copilot"

---

Review app as UX expert & Store Reviewer. Ignore backend logic/style. Focus on usability, a11y, visual flow, & App Store/Google Play compliance (privacy, IAP, crashes, metadata).
Extract top 10 critical issues. Scope independently to prevent conflicts (no overlapping files/components).
Directly EXECUTE 10 `gh issue create` commands via terminal. No conversational text.
Format:
gh issue create --title "[UX/Store]: Summary" --body "Problem: [Detail]
Location: [Screen/Component/File]
Fix: [Actionable UI/UX or compliance fix]" --label "ui-ux" --assignee "@Copilot"

gh issue create --title "[UX/Store]: Missing Privacy Policy Link in Calibration Modal" --body "Problem: While a link exists, it points to a generic placeholder. Store reviewers require a live, valid privacy policy link that specifically mentions audio data handling.
Location: lib/main.dart
Fix: Update the \_privacyPolicyUrl to a valid destination and ensure the link is clearly visible in the settings/calibration modal as per GDPR/App Store requirements." --assignee "@Copilot"

gh issue create --title "[UX/Store]: Hardcoded Accessibility Labels in Rhythm Screen" --body "Problem: Metadata and semantic labels in the Rhythm Screen are hardcoded in English, failing localization (i18n) for Japanese users and causing accessibility regressions.
Location: lib/rhythm_screen.dart
Fix: Move all semanticsLabel and tooltip strings to AppLocalizations (ARB files)." --assignee "@me"
