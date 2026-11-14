#!/usr/bin/env python3
"""Check known compression races and learn context limits from matching provider errors."""

import argparse
import ast
import io
from pathlib import Path
import re

from fix_reasoning_alias import write_with_backup


OLD = '''            # Temporary DEFER (lock held / cooldown), not evidence about compressibility:
            # refund the attempt, leave the progress blocker unarmed and proceed.
            v.compression_attempts -= 1
            v._last_preflight_pressure = None
            if v.pending_moa_prepared_request is moa_prepared_request:
                v.pending_moa_prepared_request = None
'''
NEW = '''            # A temporary skip is not evidence about compressibility: refund
            # the attempt and leave the progress blocker unarmed.
            v.compression_attempts -= 1
            v._last_preflight_pressure = None
            if v.pending_moa_prepared_request is moa_prepared_request:
                v.pending_moa_prepared_request = None
            if compression_skipped_due_to_lock(agent):
                # A gateway hygiene worker can still be summarizing after its
                # turn-hold expires. Do not send the unchanged history while
                # that worker owns compression; estimates can undercount the
                # provider's input plus output reservation.
                v.api_call_count = _refund_api_call(agent, v.api_call_count)
                agent._persist_session(v.messages, v.conversation_history)
                return _done("return", _compression_deferred_result(
                    agent, v.messages, v.api_call_count,
                ))
'''


def patch_source(text):
    tree = ast.parse(text)
    fn = next((n for n in tree.body if isinstance(n, ast.FunctionDef)
               and n.name == "run_preflight_compression"), None)
    if fn is None:
        return "unknown", text
    lines = text.splitlines(keepends=True)
    body = "".join(lines[fn.lineno - 1:fn.end_lineno])
    if NEW in body:
        return "not-affected", text
    # Only recognize the exact known branch and its existing result/refund helpers.
    names = {n.id for n in ast.walk(fn) if isinstance(n, ast.Name)}
    if body.count(OLD) != 1 or not {"_compression_deferred_result", "_refund_api_call"} <= names:
        return "unknown", text
    if 'if v.messages is _pre_api_input and (' not in body:
        return "unknown", text
    patched = text.replace(body, body.replace(OLD, NEW), 1)
    compile(patched, "turn_preflight.py", "exec")
    return "patched", patched


def reported_limit(log, model):
    """Use the latest overflow for this exact active provider/model/endpoint only."""
    if not isinstance(model, dict):
        return None
    expected = (model.get("provider"), str(model.get("base_url", "")).rstrip("/"),
                model.get("default") or model.get("model"))
    if not all(expected):
        return None
    result = None
    for line in log.splitlines():
        route = re.search(r'provider=(\S+) base_url=(\S+) model=(\S+) summary=HTTP 400:', line)
        if not route or (route[1], route[2].rstrip("/"), route[3]) != expected:
            continue
        if '"type":"context_length"' not in line.replace(" ", "").replace('\\"', '"'):
            continue
        match = re.search(r'"limit"\s*:\s*(\d+)', line.replace('\\"', '"'))
        if match and 1024 <= int(match[1]) <= 10_000_000:
            result = int(match[1])
    return result


def update_config(config, limit, tune_wait):
    changes = []
    model = config.get("model")
    if limit and isinstance(model, dict):
        current = model.get("context_length")
        if current is None or (type(current) is int and current > limit):
            model["context_length"] = limit
            changes.append(f"model.context_length = {limit} (dari error provider yang cocok)")
    if tune_wait:
        compression = config.setdefault("compression", {})
        if isinstance(compression, dict):
            current = compression.get("hygiene_max_turn_hold_seconds", 10)
            if type(current) in (int, float) and current < 120:
                compression["hygiene_max_turn_hold_seconds"] = 120
                changes.append("compression.hygiene_max_turn_hold_seconds = 120")
    return changes


def load_yaml(text):
    try:
        from ruamel.yaml import YAML
        codec = YAML()
        codec.preserve_quotes = True
        def dump(value):
            output = io.StringIO()
            codec.dump(value, output)
            return output.getvalue()
        return codec.load(text), dump
    except ImportError:
        import yaml
        return yaml.safe_load(text), lambda value: yaml.safe_dump(value, allow_unicode=True, sort_keys=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = args.source_dir / "agent" / "turn_preflight.py"
    status = "unknown"
    if source.is_file():
        status, patched = patch_source(source.read_text(encoding="utf-8"))
        if status == "patched" and not args.check:
            backup = write_with_backup(source, patched, ".bak-exsala-compression")
            print(f"✓ Compression fix: pola bug diperbaiki; backup: {backup}")
        elif status == "patched":
            print("⚠ Compression fix: pola bug ditemukan (--check; belum diubah)")
        elif status == "not-affected":
            print("✓ Compression fix: patch sudah ada; tidak ada perubahan source")
        else:
            print("⚠ Compression fix: struktur belum dikenali; skip source")
    else:
        print("⚠ Compression fix: source tidak ditemukan; skip source")
    if args.config and args.config.is_file():
        config, dump = load_yaml(args.config.read_text(encoding="utf-8"))
        if not isinstance(config, dict):
            raise ValueError("Config Hermes harus berupa mapping")
        log = args.log.read_text(encoding="utf-8", errors="replace") if args.log and args.log.is_file() else ""
        limit = reported_limit(log, config.get("model"))
        changes = update_config(config, limit, status in ("patched", "not-affected"))
        if changes:
            if not args.check:
                write_with_backup(args.config, dump(config), ".bak-exsala-compression")
            print(("→ Rencana: " if args.check else "✓ ") + "; ".join(changes))
        if limit is None:
            print("• Context limit: belum ada error provider yang cocok; batas model tidak ditebak")
    if status == "patched" and not args.check:
        print("→ Restart Hermes DAN gateway agar patch dimuat")


if __name__ == "__main__":
    main()
