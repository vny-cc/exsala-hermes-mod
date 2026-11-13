#!/usr/bin/env python3
"""Apply the known remote-custom reasoning replay fix, without importing Hermes."""

import argparse
import ast
import os
from pathlib import Path
import shutil
import tempfile


def patch_source(text):
    """Return (status, source); refuse layouts whose semantics we cannot verify."""
    tree = ast.parse(text)
    assignments = {
        node.targets[0].id: node.value
        for node in tree.body
        if isinstance(node, ast.Assign) and len(node.targets) == 1
        and isinstance(node.targets[0], ast.Name)
    }
    for node in tree.body:
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            assignments[node.target.id] = node.value
    table = assignments.get("_REASONING_CARRIER_ROUTES")
    local = assignments.get("_LOCAL_CARRIERS")
    if not isinstance(table, (ast.Tuple, ast.List)):
        return "unknown", text
    if not (isinstance(local, ast.Call) and isinstance(local.func, ast.Name)
            and local.func.id == "frozenset" and len(local.args) == 1
            and isinstance(local.args[0], ast.Set)
            and {ast.dump(n) for n in local.args[0].elts}
            == {ast.dump(ast.Name(id=n, ctx=ast.Load())) for n in ("RC", "R")}):
        return "unknown", text
    route = next((n for n in tree.body if isinstance(n, ast.FunctionDef)
                  and n.name == "route_reasoning_carriers"), None)
    if route is None or not any(isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
                                and n.func.id == "is_local_endpoint" for n in ast.walk(route)):
        return "unknown", text
    matches = []
    for row in table.elts:
        if not isinstance(row, (ast.Tuple, ast.List)) or len(row.elts) != 3:
            return "unknown", text
        carrier, providers, _hosts = row.elts
        if not (isinstance(providers, ast.Call) and isinstance(providers.func, ast.Name)
                and providers.func.id == "frozenset" and len(providers.args) == 1
                and isinstance(providers.args[0], ast.Set)):
            return "unknown", text
        values = providers.args[0].elts
        if not all(isinstance(n, ast.Constant) and isinstance(n.value, str) for n in values):
            return "unknown", text
        for index, value in enumerate(values):
            if value.value == "custom":
                if not (isinstance(carrier, ast.Name) and carrier.id == "_LOCAL_CARRIERS"
                        and len(values) > 1):
                    return "unknown", text
                matches.append((values, index))
    if not matches:
        return "not-affected", text
    if len(matches) != 1:
        return "unknown", text
    values, index = matches[0]
    # AST columns are UTF-8 byte offsets. Remove one set element and its comma,
    # keeping every other byte (including local endpoint detection) unchanged.
    lines = text.encode("utf-8").splitlines(keepends=True)

    def offset(node, end=False):
        line = node.end_lineno if end else node.lineno
        col = node.end_col_offset if end else node.col_offset
        return sum(map(len, lines[:line - 1])) + col

    if index < len(values) - 1:
        start, end = offset(values[index]), offset(values[index + 1])
    else:
        start, end = offset(values[index - 1], True), offset(values[index], True)
    patched = (text.encode("utf-8")[:start] + text.encode("utf-8")[end:]).decode("utf-8")
    compile(patched, "message_sanitization.py", "exec")
    return "patched", patched


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path, help="Hermes source checkout")
    parser.add_argument("--check", action="store_true", help="Detect only; do not write")
    args = parser.parse_args()
    path = args.source_dir / "agent" / "message_sanitization.py"
    if not path.is_file():
        print(f"⚠ Reasoning fix: source tidak ditemukan: {path}; skip")
        return
    status, patched = patch_source(path.read_text(encoding="utf-8"))
    if status == "not-affected":
        print("✓ Reasoning fix: pola bug tidak ada; tidak ada perubahan")
    elif status == "unknown":
        print("⚠ Reasoning fix: struktur Hermes belum dikenali; skip tanpa perubahan")
    elif args.check:
        print("⚠ Reasoning fix: pola bug ditemukan (--check; belum diubah)")
    else:
        backup = path.with_name(path.name + ".bak-exsala-reasoning")
        try:
            with backup.open("xb") as output:
                output.write(path.read_bytes())
        except FileExistsError:
            pass
        fd, name = tempfile.mkstemp(prefix=".exsala-reasoning-", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="") as output:
                output.write(patched)
            shutil.copymode(path, name)
            os.replace(name, path)
        finally:
            if os.path.exists(name):
                os.unlink(name)
        print(f"✓ Reasoning fix: pola bug ditemukan dan diperbaiki; backup: {backup}")
        print("→ Restart proses Hermes DAN gateway agar patch dimuat; /new saja tidak cukup")


if __name__ == "__main__":
    main()
