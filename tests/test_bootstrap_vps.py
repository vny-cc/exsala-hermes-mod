import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "bootstrap-vps.sh"


class BootstrapTests(unittest.TestCase):
    def test_plan_and_unknown_arguments(self):
        plan = subprocess.run(["bash", str(SCRIPT), "--plan"], capture_output=True, text=True)
        self.assertEqual(plan.returncode, 0)
        self.assertIn("Fresh root VPS", plan.stdout)
        invalid = subprocess.run(["bash", str(SCRIPT), "--invalid"], capture_output=True, text=True)
        self.assertEqual(invalid.returncode, 2)

    def test_wrong_user_stops_before_package_install(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_id = root / "id"
            fake_id.write_text("#!/bin/sh\necho 1000\n")
            fake_id.chmod(0o755)
            result = subprocess.run(["bash", str(SCRIPT)],
                                    env={**os.environ, "PATH": str(root) + ":" + os.environ["PATH"]},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("root", result.stderr)

    def test_shell_and_generated_shells_and_toml_parse(self):
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True, capture_output=True)
        text = SCRIPT.read_text()
        for body in re.findall(r"<<'SHELL'\n(.*?)\nSHELL", text, re.S):
            subprocess.run(["bash", "-n"], input=body, text=True, check=True, capture_output=True)
        config = re.search(r"<<'TOML'\n(.*?)\nTOML", text, re.S)[1]
        parsed = tomllib.loads(config)
        self.assertEqual(parsed["terminal"]["shell_mode"], "non_login")


if __name__ == "__main__":
    unittest.main()
