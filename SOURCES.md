# Source notes

This is an independent, unofficial PowerShell/WPF implementation for the user.
It does not bundle, install, or execute code from the community repositories.
No OpenAI endorsement or complete third-party security audit is implied.

Official authentication and local state references:
- https://learn.chatgpt.com/docs/auth
- https://learn.chatgpt.com/docs/config-file/environment-variables

Community implementations whose source was read for workflow ideas:
- https://github.com/cguru/Codex-Account-Switcher-Windows/blob/main/src/Services.cs
  Reviewed source SHA: 68fc62f31b82374ed3af41593fa3fdb81d96ab8d
  Useful ideas: package-path process identification; normal-close then optional
  forced close; explicit desktop handoff and restart.
- https://github.com/karthiknl0/codex-account-switcher/blob/main/src/codex-switch.ps1
  Reviewed source SHA: 613ffe35293f3aeee2f7aafeb678fb93c05451ab
- https://github.com/karthiknl0/codex-account-switcher/blob/main/src/codex-add.ps1
  Reviewed source SHA: e7d3f6e8b265f7521c34f81116ab3bd049357825
  Useful ideas: official CLI sign-in, account snapshot, Store launch discovery.

The third-party codex-auth dependency is intentionally not used here. This
implementation stores encrypted local auth snapshots directly and invokes the
bundled CLI when present (otherwise the CLI on PATH) for a one-time sign-in
in a private temporary CODEX_HOME. Verify the PATH entry before using this
fallback on an unfamiliar machine.
It does not assume that checking a local identity proves server-side access.

File: Core.ps1 contains all account and process operations. The UI does not
evaluate shell strings, download code, invoke logout or call token endpoints.
Compatibility target: Windows PowerShell 5.1 / desktop Windows 11.
