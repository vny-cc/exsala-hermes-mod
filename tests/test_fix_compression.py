from copy import deepcopy
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import fix_compression as fix


SOURCE = '''def run_preflight_compression(agent, v):
    _compression_deferred_result, _refund_api_call
    _pre_api_input = v.messages
    moa_prepared_request = None
    if True:
        if v.messages is _pre_api_input and (
            compression_skipped_due_to_lock(agent) or compression_blocked_transiently(agent)
        ):
''' + fix.OLD + '''        else:
            return "compressed"
    return "send"
'''
MODEL = {"provider": "custom", "base_url": "https://gateway.example/v1", "default": "uncen"}
LOG = ('provider=custom base_url=https://gateway.example/v1 model=uncen summary=HTTP 400: '
       '{"message":"Invalid request","details":{"type":"context_length","limit":262144,"actual":281597}}')


class CompressionFixTests(unittest.TestCase):
    def test_lock_loser_never_sends_and_refunds_attempt(self):
        namespace = {
            "compression_skipped_due_to_lock": lambda agent: True,
            "compression_blocked_transiently": lambda agent: False,
            "_refund_api_call": lambda agent, count: count - 1,
            "_compression_deferred_result": lambda *args: "deferred",
            "_done": lambda action, result: (action, result),
        }
        status, text = fix.patch_source(SOURCE)
        self.assertEqual(status, "patched")
        exec(text, namespace)
        agent = SimpleNamespace(_persist_session=Mock())
        v = SimpleNamespace(messages=[], conversation_history=[], compression_attempts=1,
                            pending_moa_prepared_request=None, api_call_count=1)
        self.assertEqual(namespace["run_preflight_compression"](agent, v), ("return", "deferred"))
        self.assertEqual(v.api_call_count, 0)
        self.assertEqual(v.compression_attempts, 0)
        agent._persist_session.assert_called_once_with(v.messages, v.conversation_history)
        self.assertEqual(fix.patch_source(text), ("not-affected", text))

    def test_unknown_layout_is_unchanged(self):
        for text in ("x = 1\n", SOURCE.replace(fix.OLD, "            pass\n")):
            self.assertEqual(fix.patch_source(text), ("unknown", text))

    def test_limit_requires_exact_route_and_context_error(self):
        self.assertEqual(fix.reported_limit(LOG, MODEL), 262144)
        self.assertEqual(fix.reported_limit(LOG.replace('"', '\\"'), MODEL), 262144)
        for log in (LOG.replace("uncen", "other"), LOG.replace("gateway.example", "other.example"),
                    LOG.replace("provider=custom", "provider=openai"),
                    LOG.replace("context_length", "output_limit")):
            self.assertIsNone(fix.reported_limit(log, MODEL))
        self.assertIsNone(fix.reported_limit("", MODEL))

    def test_config_only_shrinks_and_preserves_secrets_and_higher_wait(self):
        config = {"model": {**MODEL, "api_key": "${MY_KEY}", "context_length": 1000000},
                  "compression": {"enabled": True, "hygiene_max_turn_hold_seconds": 180}}
        self.assertTrue(fix.update_config(config, 262144, True))
        self.assertEqual(config["model"]["context_length"], 262144)
        self.assertEqual(config["model"]["api_key"], "${MY_KEY}")
        self.assertEqual(config["compression"]["hygiene_max_turn_hold_seconds"], 180)
        self.assertEqual(fix.update_config(config, 262144, True), [])
        self.assertEqual(fix.update_config(config, 1000000, True), [])
        config = {"model": deepcopy(MODEL)}
        fix.update_config(config, None, False)
        self.assertNotIn("context_length", config["model"])
        self.assertNotIn("compression", config)

    def test_cli_check_and_repeat_install(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "agent" / "turn_preflight.py"
            source.parent.mkdir()
            source.write_text(SOURCE)
            command = [sys.executable, str(Path(fix.__file__)), str(root)]
            subprocess.run([*command, "--check"], check=True, capture_output=True)
            self.assertEqual(source.read_text(), SOURCE)
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(source.with_name(source.name + ".bak-exsala-compression").read_text(), SOURCE)
            fixed = source.read_bytes()
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(source.read_bytes(), fixed)


if __name__ == "__main__":
    unittest.main()
