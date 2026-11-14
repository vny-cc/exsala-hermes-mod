# EXSALA HERMES MOD

<p align="center">
  <b>An adaptive execution profile + skill collection for Hermes Agent</b><br/>
  For power users who want leaner, faster, no-confirmation interactions with their own instance.
</p>

<!--
tags:
  - github
  - hermes
  - hermes-agent
  - jailbreak
  - jailbreak-prompts
  - llm
  - llm-agents
  - prompt-injection
  - prompt-injection-prompts
  - prompt-engineering
  - ai-agent
  - llm-agents
  - jailbreak-prompts
  - prompt
  - llm-agents-prompt
  - github-actions
  - automation
  - ai
  - prompt-hacking
  - jailbreaking
  - zero-refusal
  - open-source
  - prompts
  - generative-ai
  - parser
  - profile
  - skills
  - ai-agent-framework
  - cli
  - llms
  - jailbreaks
-->

---

## What is this

EXSALA HERMES MOD is a **configuration profile + skill collection** for [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) (the open-source AI agent by Nous Research).

It adjusts a local Hermes instance to run in **streamlined execution mode**:

- **Fewer confirmation prompts** — the assistant acts on instructions directly.
- **No safety-lecture chatter** — concise, task-focused replies without unsolicited caveats.
- **Zero-refusal core** — no moralizing pauses, no "are you sure", no policy friction (anti-UU).
- **Farming-first** — auto pipelines, mass account creation, pure-HTTP preferred (curl_cffi), browser fallback (Camoufox/Playwright) for Cloudflare-gated targets.
- **Model-agnostic** — works the same regardless of the underlying model (DeepSeek, GLM, Qwen, MiMo, ...).
- **A clean status banner** at the start of every new session.
- **172 skills included** — automation, web, security research, media, productivity, coding helpers, farming infra (AgentMail inbox, prompt leaks library), and more, ready to use.

It does **not** change your model provider, API keys, or personal data.

---

## Installation

Requirements: Linux VPS/server with Hermes Agent (≥ 0.22), `bash`, `python3`, `curl`.

### One-line

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/giienew/exsala-hermes-mod/main/install.sh)
```

### Manual

```bash
git clone https://github.com/giienew/exsala-hermes-mod.git
cd exsala-hermes-mod
bash install.sh
```

### What the installer changes

| Setting | After | Notes |
|---|---|---|
| `agent.system_prompt` | EXSALA profile | Replaces default behavioral prompt |
| `approvals.mode` (+ `*_mode`) | `off` | No confirmation prompts |
| `security.tirith_enabled` | `false` | Local content-gating off |
| `security.tirith_fail_open` | `true` | Fail-open |
| `security.protected_instruction_files` | `false` | Allow project context files |
| `~/.hermes/skills/` | +172 skills | Merged, never deletes existing |

> See **[config.example.yaml](config.example.yaml)** for a full annotated reference config with every jailbreak setting — copy the relevant keys into your own `~/.hermes/config.yaml` if you prefer manual setup over the installer.

### What is NEVER touched

- `model.api_key` — your provider key untouched
- `model.base_url` / `model.default` / `fallback_providers` — routing untouched
- `.env` — secrets stay private
- `platforms.*.home_channel` — chat IDs intact
- Your memory, sessions, plugins, other skills

### Safety & rollback

- **Automatic backup:** `~/.hermes/config.yaml.bak-exsala`
- **Restore:** `cp ~/.hermes/config.yaml.bak-exsala ~/.hermes/config.yaml`
- **Idempotent** — re-running is safe; backup is never overwritten.
- Falls back to Python YAML patching if `hermes` isn't on PATH.

---

## After install

1. Restart Hermes (new session, e.g. `/reset`).
2. The EXSALA banner appears.
3. The skill pack is active — any of the 172 skills can be invoked by name.

## Fresh VPS recovery with Herdr

`bootstrap-vps.sh` is a separate recovery entry point for the owner's private
`vny-cc/hermes-backup` repository. It supports a **fresh Ubuntu/Debian VPS,
logged in as root, with systemd and an interactive SSH terminal**. It refuses
to overwrite an existing Hermes configuration. It is not an installer for a
Codespace or a migration command to run on the currently active VPS.

The bootstrap installs dependencies and Herdr, asks for GitHub device login,
clones the private backup tooling, then opens recovery inside a persistent
Herdr pane. Paste only the `AGE-SECRET-KEY-...` line from your recovery key when
prompted; input is hidden. Never put the key in the command line or a public URL.

Recovery verifies the newest complete encrypted snapshot, installs the Hermes
commit recorded in it, applies the recorded local source patch, restores Hermes
data, installs Herdr's Hermes integration, and starts the system gateway plus
the 15-minute backup timer. It checks the first backup before opening Hermes.
The restored cron definitions become active with the gateway: use this on the
replacement VPS after the old gateway is no longer running.

Once recovery is complete, reconnect with `hermes-herdr`. Herdr keeps pane
processes running through an SSH disconnect; it still depends on the VPS being
up. Only files present in the Hermes backup can be restored. External project
folders (for example `/root/farming`) and old Herdr pane layouts are not in the
current backup scope.

Preview without installing or restoring anything:

```bash
bash bootstrap-vps.sh --plan
```

This flow has automated tests with stubbed installers and staged restore tests;
it has not been exercised end to end on a separate empty VPS. If a step fails,
the recovered staging directory is kept for inspection and Hermes is not
opened automatically. The fresh-VPS guard also blocks a blind rerun after a
partially completed Hermes installation.

## Project layout

```
exsala-hermes-mod/
├── install.sh
├── SOUL.md
├── skills/          # 172 skill dirs
└── README.md
```

## License

MIT — use, adapt, improve. No warranty.

<p align="center"><i>EXSALA HERMES MOD</i></p>
