import ast
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "fix_reasoning_alias.py"
spec = importlib.util.spec_from_file_location("fix_reasoning_alias", SCRIPT)
fix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fix)

SOURCE = '''# UTF-8: alasan → provider
RC, R = "reasoning_content", "reasoning"
_LOCAL_CARRIERS = frozenset({RC, R})
_DEFAULT_CARRIERS = frozenset({RC})
_REASONING_CARRIER_ROUTES: tuple = (
    (_LOCAL_CARRIERS, frozenset({"ollama-cloud", "custom", "lmstudio", "upstage"}), ("ollama.com",)),
)
def is_local_endpoint(url):
    return url.startswith("http://127.0.0.1:")
def route_reasoning_carriers(provider, base_url):
    carriers = next((c for c, providers, hosts in _REASONING_CARRIER_ROUTES
                     if provider in providers), None)
    if carriers is None:
        carriers = _LOCAL_CARRIERS if is_local_endpoint(base_url) else _DEFAULT_CARRIERS
    return carriers
'''


class ReasoningFixTests(unittest.TestCase):
    def test_remote_custom_changes_but_local_and_other_providers_survive(self):
        before = {}
        exec(SOURCE, before)
        self.assertEqual(before["route_reasoning_carriers"]("custom", "https://gateway.example/v1"),
                         {"reasoning", "reasoning_content"})
        status, patched = fix.patch_source(SOURCE)
        self.assertEqual(status, "patched")
        after = {}
        exec(patched, after)
        route = after["route_reasoning_carriers"]
        self.assertEqual(route("custom", "https://gateway.example/v1"), {"reasoning_content"})
        self.assertEqual(route("custom", "http://127.0.0.1:8080/v1"), {"reasoning", "reasoning_content"})
        self.assertEqual(route("ollama-cloud", "https://ollama.com/v1"), {"reasoning", "reasoning_content"})
        self.assertEqual(patched, SOURCE.replace('"custom", ', ""))
        self.assertEqual(fix.patch_source(patched), ("not-affected", patched))

    def test_multiline_and_last_element(self):
        for providers in ('"custom",\n "ollama-cloud"', '"ollama-cloud",\n "custom"'):
            source = SOURCE.replace('"ollama-cloud", "custom", "lmstudio", "upstage"', providers)
            with self.subTest(providers=providers):
                status, patched = fix.patch_source(source)
                self.assertEqual(status, "patched")
                ast.parse(patched)
                self.assertNotIn('"custom"', patched)

    def test_unknown_versions_are_never_rewritten(self):
        for source in ("x = 1\n", SOURCE.replace("_LOCAL_CARRIERS = frozenset({RC, R})",
                                               "_LOCAL_CARRIERS = frozenset({RC})"),
                       SOURCE.replace("is_local_endpoint(base_url)", "False"),
                       SOURCE.replace('"ollama-cloud", "custom", "lmstudio", "upstage"', '"custom"')):
            with self.subTest(source=source):
                self.assertEqual(fix.patch_source(source), ("unknown", source))

    def test_cli_check_backup_permissions_and_repeat_install(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "agent" / "message_sanitization.py"
            path.parent.mkdir()
            path.write_text(SOURCE)
            path.chmod(0o640)
            backup = path.with_name(path.name + ".bak-exsala-reasoning")
            def run(*args):
                return subprocess.run([sys.executable, str(SCRIPT), str(root), *args],
                                      check=True, capture_output=True, text=True).stdout
            self.assertIn("pola bug ditemukan", run("--check"))
            self.assertEqual(path.read_text(), SOURCE)
            self.assertFalse(backup.exists())
            self.assertIn("diperbaiki", run())
            self.assertEqual(backup.read_text(), SOURCE)
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
            fixed = path.read_bytes()
            self.assertIn("pola bug tidak ada", run())
            self.assertEqual(path.read_bytes(), fixed)
            self.assertEqual(backup.read_text(), SOURCE)

    def test_cli_missing_source_skips(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(SCRIPT), directory],
                                    check=True, capture_output=True, text=True)
            self.assertIn("source tidak ditemukan", result.stdout)


if __name__ == "__main__":
    unittest.main()
