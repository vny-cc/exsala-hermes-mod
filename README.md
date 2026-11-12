<div align="center">

# ⚡ EXSALA HERMES MOD

### Adaptive Agent Profile · 172 Skills · Reliable Installer

**Extend your Hermes Agent with an execution-focused profile, a comprehensive skill collection, and an automated installation experience.**

[![Hermes Agent](https://img.shields.io/badge/Powered_by-Hermes_Agent-6366F1?style=for-the-badge)](https://hermes-agent.nousresearch.com/docs/)
[![Platform](https://img.shields.io/badge/Platform-Linux-22C55E?style=for-the-badge&logo=linux&logoColor=white)](#requirements)
[![Python](https://img.shields.io/badge/Python-3.x-3776AB?style=for-the-badge&logo=python&logoColor=white)](#requirements)
[![Skills](https://img.shields.io/badge/Skills-172-F59E0B?style=for-the-badge)](#skill-management)

[Installation](#-quick-start) · [Features](#-features) · [Configuration](#-configuration) · [Testing](#-automated-testing) · [Credits](#-credits)

---

**Originally developed by [Gienetic](https://github.com/giienew)**

Installer improvements maintained by **[vny-cc](https://github.com/vny-cc)**

</div>

## 📖 Overview

**EXSALA HERMES MOD** is a configuration profile and skill collection for [Hermes Agent](https://hermes-agent.nousresearch.com/docs/), the open-source AI agent developed by Nous Research.

It provides an execution-oriented agent profile through `SOUL.md`, together with 172 bundled skills covering automation, development, research, productivity, and more.

This fork improves the installation experience with dependency automation, atomic configuration updates, conflict-safe skill installation, and automated testing.

> [!NOTE]
> This fork preserves existing Hermes approval and security settings. The behavioral profile does not override the underlying model's or runtime's safeguards.

## ✨ Features

| Feature | Description |
|:---|:---|
| ⚡ **Adaptive Agent Profile** | Execution-oriented behavioral profile through `SOUL.md` |
| 🧩 **172 Bundled Skills** | Automation, development, research, productivity, and other capabilities |
| 🚀 **One-Line Installation** | Install without manually cloning the repository |
| 📦 **Automatic Dependencies** | Sets up Python YAML dependencies using an isolated virtual environment |
| 🔍 **Preflight Validation** | Checks installation requirements without modifying Hermes |
| 🔄 **Atomic Configuration** | Validates YAML before replacing the original configuration |
| 💾 **Automatic Backups** | Creates timestamped backups when configuration changes |
| 🛡️ **Security Preservation** | Keeps existing approval and security settings |
| 🔁 **Rollback Support** | Attempts to restore changes after supported installation failures |
| 🧠 **Idempotent Installation** | Skips unchanged configuration and identical skills |
| ⚔️ **Conflict Protection** | Preserves modified skills and reports conflicts |
| 🧪 **Automated Testing** | Integration, rollback, and dependency test suites |

## 🚀 Quick Start

### Requirements

Make sure your environment has:

- Linux (Ubuntu/Debian recommended)
- An existing Hermes Agent installation
- Bash, Git, curl, and GNU coreutils
- Python 3 with virtual environment support
- Internet access for downloading missing dependencies
- Write access to your Hermes configuration and skills directory

### One-Line Installation

Run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vny-cc/exsala-hermes-mod/fix/installer/bootstrap.sh)
```

The bootstrap downloads the complete repository, including `SOUL.md` and the bundled skills, before running the main installer.

**Check your environment first:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vny-cc/exsala-hermes-mod/fix/installer/bootstrap.sh) --check
```

> [!TIP]
> Review remote installation scripts before running them, particularly on servers with privileged access.

### Manual Installation

Prefer inspecting the source before installation? Clone the repository:

```bash
git clone https://github.com/vny-cc/exsala-hermes-mod.git
cd exsala-hermes-mod
git switch fix/installer
```

Run the preflight check:

```bash
bash install.sh --check
```

Install EXSALA:

```bash
bash install.sh
```

Then restart Hermes or start a new agent session.

## ⚙️ Configuration

### What Changes?

| Component | Installer Behavior |
|:---|:---|
| `agent.system_prompt` | Applies the EXSALA profile from `SOUL.md` |
| `platforms.telegram.extra.rich_messages` | Enables rich messages |
| `platforms.telegram.extra.allow_cjk_rich_messages` | Enables CJK rich-message support |
| `approvals.*` | Preserves existing values |
| `security.tirith_enabled` | Preserves existing value |
| `security.tirith_fail_open` | Preserves existing value |
| `security.protected_instruction_files` | Preserves existing value |
| Model and API configuration | Not intentionally modified |
| Existing skills | Identical skills skipped; conflicting skills preserved |

### Custom Hermes Home

Specify a custom installation directory:

```bash
HERMES_HOME=/path/to/.hermes bash install.sh
```

### Custom SOUL Profile

Use your own agent profile:

```bash
SOUL_FILE=/path/to/SOUL.md bash install.sh
```

### Custom Python Interpreter

```bash
PYTHON_BIN=/path/to/python3 bash install.sh
```

### Preflight Mode

```bash
bash install.sh --check
```

This performs basic read-only checks for the configuration, Python interpreter, SOUL file, and skill directory.

## 🧩 Skill Management

EXSALA includes **172 skill directories**.

The installer uses a conflict-aware approach to avoid overwriting existing user modifications.

| Scenario | Action |
|:---|:---|
| New skill | ✅ Install |
| Identical skill | ⏭️ Skip |
| Existing modified skill | 🛡️ Preserve and report conflict |
| Failed skill copy | 🔁 Clean temporary files and attempt rollback |

Skill files are staged in temporary directories before being moved into their destination.

> [!IMPORTANT]
> Review bundled skills before giving an agent access to sensitive files, credentials, or privileged commands.

## 🛡️ Backup & Recovery

### Automatic Backups

When the Hermes configuration changes, the installer generates a timestamped backup:

```text
~/.hermes/config.yaml.bak-exsala-YYYYMMDD-HHMMSS-ffffff
```

The actual backup location follows `HERMES_HOME`.

If the configuration is unchanged, the installer avoids rewriting it and skips creating an additional backup.

### Automatic Rollback

If an installation fails under a supported failure scenario, the installer attempts to:

1. Restore the original Hermes configuration.
2. Remove newly installed skills from the failed attempt.
3. Preserve pre-existing skills and user modifications.

> [!WARNING]
> Rollback is best-effort, not fully crash-safe. Forced termination (`SIGKILL`), power loss, filesystem errors, or concurrent modifications may require manual recovery.

### Manual Recovery

List available backups:

```bash
ls -lt ~/.hermes/config.yaml.bak-exsala-*
```

Restore a selected backup:

```bash
cp -p /path/to/selected-backup ~/.hermes/config.yaml
```

If your Hermes home differs from `~/.hermes`, adjust the destination accordingly.

## 🧪 Automated Testing

This fork includes three automated test suites.

| Test Suite | Coverage |
|:---|:---|
| `integration.sh` | Configuration, permissions, idempotency, skill conflicts, and malformed YAML |
| `rollback.sh` | Recovery after simulated skill installation failure |
| `dependencies.sh` | Automatic dependency installation in a clean Python virtual environment |

### Run All Tests

```bash
bash tests/integration.sh
bash tests/rollback.sh
bash tests/dependencies.sh
```

The tests use temporary Hermes directories rather than intentionally modifying your active Hermes configuration.

The dependency test may require access to PyPI.

<details>
<summary><b>Previously verified test results</b></summary>

The following checks passed during development:

- ✅ Integration tests: 6/6
- ✅ Rollback assertions: 3/3
- ✅ Clean environment checks: 4/4

These results cover the tested environments and scenarios only; they do not guarantee full compatibility or crash recovery.

</details>

## 📁 Project Structure

```text
exsala-hermes-mod/
├── bootstrap.sh
├── install.sh
├── SOUL.md
├── config.example.yaml
├── skills/
│   └── 172 skill directories
├── tests/
│   ├── integration.sh
│   ├── rollback.sh
│   └── dependencies.sh
└── README.md
```

## 🔐 Security Considerations

This project supplies instructions and skills to an AI agent environment.

- Review `SOUL.md` and bundled skills before installation.
- Keep approval and security protections enabled as appropriate.
- Avoid unrestricted root permissions unless operationally necessary.
- Protect API keys, environment files, and other credentials.
- Test upgrades in an isolated environment first.
- Keep Hermes and its dependencies updated.

Preserving existing security settings does not guarantee the safety of every agent action or bundled skill.

## 🤝 Credits

### Original Project

**Gienetic**

[giienew/exsala-hermes-mod](https://github.com/giienew/exsala-hermes-mod)

Original EXSALA profile, skill collection, and project concept.

### Fork & Installer Improvements

**vny-cc**

[vny-cc/exsala-hermes-mod](https://github.com/vny-cc/exsala-hermes-mod)

Improvements include:

- Python dependency automation
- Preflight validation
- Atomic YAML configuration updates
- Timestamped backups
- Rollback handling
- Conflict-safe skill installation
- One-line bootstrap installation
- Automated integration and dependency testing

## 📜 License

Refer to the upstream project's licensing terms. Verify the applicable license and redistribution permissions before publishing or distributing under a specific license.

---

<div align="center">

### ⚡ EXSALA HERMES MOD

**More reliable installation. Safer configuration management. Powerful agent capabilities.**

[Original Project](https://github.com/giienew/exsala-hermes-mod) · [Maintained Fork](https://github.com/vny-cc/exsala-hermes-mod)

</div>
