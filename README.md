EXSALA HERMES MOD
An Adaptive Execution Profile & Skill Collection for Hermes Agent

A configuration profile and collection of 172 skills for [Hermes Agent](https://hermes-agent.nousresearch.com/docs/), with an improved installation system focused on reliability, automation, compatibility, and safe configuration management.

Originally developed by Gienetic. This fork is maintained by [vny-cc](https://github.com/vny-cc).
- Adaptive Execution Profile — Configurable agent behavior through SOUL.md.
- 172 Bundled Skills — Automation, web, productivity, research, development, and other capabilities.
- One-Line Installation — Install the complete package without manually cloning the repository.
- Automatic Dependencies — Automatically prepares Python YAML dependencies in an isolated virtual environment.
- Preflight Validation — Check your system before installation.
- Atomic Configuration Updates — Validate changes before replacing the original configuration.
- Automatic Backups — Timestamped backups when configuration changes.
- Automatic Rollback — Best-effort restoration after supported installation failures.
- Conflict-Safe Skill Installation — Protects existing and modified skills.
- Idempotent Installation — Skips identical configurations and skills.
- Security Preservation — Keeps existing Hermes security and approval settings.
- Linux (Ubuntu/Debian recommended)
- Hermes Agent already installed
- Bash, Git, curl, and GNU coreutils
- Python 3 with venv support
- Internet access when dependencies must be downloaded
- Appropriate file permissions for the Hermes directory
Install EXSALA Hermes Mod using a single command:
```
bash <(curl -fsSL https://raw.githubusercontent.com/vny-cc/exsala-hermes-mod/fix/installer/bootstrap.sh)
```
The bootstrap automatically downloads the complete repository, including SOUL.md and the skill pack, before running the installer.

Preflight check only:
```
bash <(curl -fsSL https://raw.githubusercontent.com/vny-cc/exsala-hermes-mod/fix/installer/bootstrap.sh) --check
```
This checks the system without modifying your Hermes installation.
```
git clone https://github.com/vny-cc/exsala-hermes-mod.git
cd exsala-hermes-mod
git switch fix/installer

bash install.sh --check
bash install.sh
```
```
HERMES_HOME=/path/to/.hermes bash install.sh
```
```
SOUL_FILE=/path/to/SOUL.md bash install.sh
```
```
PYTHON_BIN=/path/to/python3 bash install.sh
```
Component	Behavior
agent.system_prompt	Applies the EXSALA profile
Telegram rich messages	Enables supported rich-message options
approvals.*	Preserves existing settings
security.tirith_enabled	Preserves existing value
security.tirith_fail_open	Preserves existing value
security.protected_instruction_files	Preserves existing value
Model provider / API keys	Not intentionally modified
Existing skills	Preserved when identical or conflicting
Unlike the original installer, this fork does not automatically disable Hermes approval or security controls.

The behavioral profile may influence how the agent responds, but the underlying model and runtime safeguards continue to apply.
The installer handles skill installation according to the following rules:
Condition	Action
New skill	Install
Identical existing skill	Skip
Existing skill with different content	Preserve and report conflict
Skill copy failure	Clean temporary files and attempt rollback
Skill installation uses temporary directories to reduce the risk of partially copied skills.
When config.yaml changes, the installer creates a timestamped backup:
```
~/.hermes/config.yaml.bak-exsala-YYYYMMDD-HHMMSS-ffffff
```
The actual location follows the configured HERMES_HOME.

If the configuration is already identical, no new backup is created.
If an installation fails in a supported failure scenario, the installer attempts to:
1. Restore the previous Hermes configuration.
2. Remove newly installed skills from that installation attempt.
3. Preserve pre-existing skill directories.
Limitations: Rollback is best-effort and does not guarantee recovery from SIGKILL, power loss, storage failure, or concurrent modifications.
List configuration backups:
```
ls -lt ~/.hermes/config.yaml.bak-exsala-*
```
Restore the selected backup:
```
cp -p /path/to/selected-backup ~/.hermes/config.yaml
```
Replace the destination if your HERMES_HOME is different.
The installer includes three test suites.

Integration tests
```
bash tests/integration.sh
```
Tests preflight validation, configuration updates, permissions, idempotency, skill conflicts, and invalid YAML handling.

Rollback tests
```
bash tests/rollback.sh
```
Simulates skill installation failure and checks configuration recovery and cleanup.

Dependency tests
```
bash tests/dependencies.sh
```
Tests Python virtual environment creation and automatic installation of ruamel.yaml.

These tests use temporary installation directories and do not intentionally modify the active Hermes configuration. The dependency test may download packages from PyPI.
```
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
EXSALA installs an agent behavioral profile and a collection of skills.
- Review SOUL.md and bundled skills before installation.
- Maintain existing Hermes approval and security controls.
- Avoid unrestricted root permissions unless explicitly necessary.
- Protect API keys and other credentials.
- Prefer an isolated test environment for initial installation.
- Do not execute remote installation scripts without reviewing their contents and source.
This fork improves installer safety but does not guarantee the security of every bundled skill or agent action.
Original project

[Gienetic — giienew/exsala-hermes-mod](https://github.com/giienew/exsala-hermes-mod)

Fork and installer improvements

[vny-cc](https://github.com/vny-cc/exsala-hermes-mod)

Improvements include dependency automation, preflight validation, atomic configuration updates, backups, rollback handling, conflict-safe skill installation, one-line bootstrap installation, and automated testing.
Refer to the upstream project's licensing terms. Confirm the applicable license and redistribution permissions before publishing or distributing this fork under a specific license.
EXSALA HERMES MOD

An execution-oriented Hermes Agent profile with an improved, testable installation workflow.


