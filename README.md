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
git clone https://github.com/vny-cc/exsala-hermes-mod.git && bash exsala-hermes-mod/install.sh
```

### Manual

```bash
git clone https://github.com/vny-cc/exsala-hermes-mod.git
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

### Automatic Hermes reasoning compatibility fix

Every install checks the Hermes source for the known bug that sends both
`reasoning` and `reasoning_content` to remote `custom` providers. Some upstream
parsers treat these as aliases and reject the request with HTTP 400:
`duplicate field reasoning_content`.

- If the known bug is present, remove only `custom` from the local-provider
  carrier list. Remote custom endpoints then use the default `reasoning_content`
  carrier; local endpoint detection stays intact.
- If that pattern is absent, skip without changing the source. This check detects
  the known source pattern; it does not make a paid API request or guarantee that
  a provider has no other compatibility issues.
- Missing source or an unfamiliar source layout is reported and skipped.
- The original source is saved once as
  `agent/message_sanitization.py.bak-exsala-reasoning` beside the patched file.
  To undo, copy that backup over `message_sanitization.py`, then restart Hermes.

The default source location is `$HERMES_HOME/hermes-agent`, falling back to
`$HOME/.hermes/hermes-agent` for profile installs. For another checkout:

```bash
HERMES_SOURCE_DIR=/path/to/hermes-agent bash install.sh
```

To inspect without changing anything:

```bash
python3 scripts/fix_reasoning_alias.py /path/to/hermes-agent --check
```

**After a patch, restart the gateway and reopen Hermes.** `/new` and `/reset`
start a new session but do not reload Python code in a running gateway:

```bash
hermes gateway restart --detach
```

The installer does not interrupt running gateway work automatically. Hermes
updates can overwrite this local patch; rerun the installer or the helper after
an update to check again.

---

## After install

1. Restart the gateway with `hermes gateway restart --detach`, then reopen Hermes.
2. The EXSALA banner appears.
3. The skill pack is active — any of the 172 skills can be invoked by name.

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
