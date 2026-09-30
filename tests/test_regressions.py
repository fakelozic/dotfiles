"""Run with: python3 -m unittest discover -s tests -v."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


def executable(path, body):
    path.write_text(body)
    path.chmod(0o755)


class ScreenshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-screenshot-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.captures = self.root / "captures"
        self.captures.mkdir()
        self.log = self.root / "calls.jsonl"
        body = f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
event = {"command": name, "args": sys.argv[1:]}
if name == "wl-copy":
    event["input"] = sys.stdin.buffer.read().hex()
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps(event) + "\\n")
if name == "slurp":
    print(os.environ.get("MOCK_GEOMETRY", "0,0 10x10"))
    sys.exit(int(os.environ.get("MOCK_SELECTION_STATUS", "0")))
if name == "grim":
    status = int(os.environ.get("MOCK_CAPTURE_STATUS", "0"))
    if status == 0 and not os.environ.get("MOCK_EMPTY_CAPTURE"):
        Path(sys.argv[-1]).write_bytes(b"PNG fixture")
    sys.exit(status)
if name == "wl-copy":
    sys.exit(int(os.environ.get("MOCK_COPY_STATUS", "0")))
'''
        for name in ("slurp", "grim", "wl-copy"):
            executable(self.bin / name, body)
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin) + ":" + self.env["PATH"],
                        TMPDIR=str(self.captures), MOCK_LOG=str(self.log))

    def run_capture(self, mode="clipboard", **overrides):
        self.log.unlink(missing_ok=True)
        result = subprocess.run(["/bin/bash", str(REPO / "scripts/screenshot"), mode],
                                env=self.env | overrides, capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(list(self.captures.iterdir()), [], "Temporary capture leaked")
        return result, calls

    def test_cancellation_runs_no_capture_or_clipboard_for_any_mode(self):
        for mode in ("clipboard", "area", "output"):
            with self.subTest(mode=mode):
                result, calls = self.run_capture(mode, MOCK_SELECTION_STATUS="1")
                self.assertEqual(result.returncode, 0)
                self.assertEqual([call["command"] for call in calls], ["slurp"])

    def test_empty_selection_runs_no_capture_or_clipboard(self):
        result, calls = self.run_capture(MOCK_GEOMETRY="")
        self.assertEqual(result.returncode, 0)
        self.assertEqual([call["command"] for call in calls], ["slurp"])

    def test_failed_capture_does_not_touch_clipboard(self):
        result, calls = self.run_capture(MOCK_CAPTURE_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("wl-copy", [call["command"] for call in calls])

    def test_empty_capture_does_not_touch_clipboard(self):
        result, calls = self.run_capture(MOCK_EMPTY_CAPTURE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("wl-copy", [call["command"] for call in calls])

    def test_success_copies_captured_bytes_as_png(self):
        result, calls = self.run_capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[-1], {"command": "wl-copy", "args": ["--type", "image/png"],
                                    "input": b"PNG fixture".hex()})

    def test_copy_failure_is_reported_and_capture_cleaned_up(self):
        result, _ = self.run_capture(MOCK_COPY_STATUS="1")
        self.assertNotEqual(result.returncode, 0)


class EditorPrerequisiteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-editor-test-")
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name)
        for tool in ("nvim", "cc", "tree-sitter", "node", "npm", "make", "unzip", "curl", "tar"):
            self.mock(tool, "")
        self.mock("nvim", "NVIM v0.12.0")
        self.mock("tree-sitter", "tree-sitter 0.26.1")

    def mock(self, tool, output):
        executable(self.bin / tool, "#!/bin/sh\nprintf '%s\\n' '" + output + "'\n")

    def run_check(self):
        env = os.environ.copy()
        env["PATH"] = str(self.bin)
        return subprocess.run(["/bin/bash", str(REPO / "scripts/check-editor-deps")],
                              env=env, capture_output=True, text=True)

    def test_supported_versions_pass(self):
        self.assertEqual(self.run_check().returncode, 0)
        self.mock("nvim", "NVIM v0.13.0-dev")
        self.mock("tree-sitter", "tree-sitter 0.27.0")
        self.assertEqual(self.run_check().returncode, 0)

    def test_missing_tools_give_install_command(self):
        (self.bin / "node").unlink()
        (self.bin / "cc").unlink()
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cc node", result.stderr)
        self.assertIn("sudo dnf install", result.stderr)

    def test_old_neovim_is_rejected(self):
        self.mock("nvim", "NVIM v0.11.9")
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Neovim 0.12.0", result.stderr)

    def test_old_tree_sitter_is_rejected(self):
        self.mock("tree-sitter", "tree-sitter 0.26.0")
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tree-sitter-cli 0.26.1", result.stderr)

    def test_unrecognized_version_is_rejected(self):
        self.mock("nvim", "unknown version")
        self.assertNotEqual(self.run_check().returncode, 0)


@unittest.skipUnless(Path("/etc/fedora-release").exists() and os.geteuid() != 0,
                     "Installer smoke test requires Fedora and a non-root user")
class BackupTests(unittest.TestCase):
    def test_wallpapers_and_original_backups_survive_same_second_installs(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-home with spaces-") as name:
            target = Path(name)
            (target / "walls").mkdir()
            wallpapers = ("burning-earth.png", "wall.png", "wallg.png")
            for wallpaper in wallpapers:
                (target / "walls" / wallpaper).write_bytes(b"original " + wallpaper.encode())
            (target / ".vimrc").write_text("original Vim config A")
            mock = target / "mock-bin"
            mock.mkdir()
            executable(mock / "date", "#!/bin/sh\nprintf '%s\\n' '20260930-120000'\n")
            env = os.environ.copy()
            env.update(DOTFILES_TARGET_HOME=str(target), PATH=str(mock) + ":" + env["PATH"])
            args = ["bash", str(REPO / "install.sh"), "--files-only", "--skip-nvidia",
                    "--skip-shell-change", "--skip-reload"]
            first = subprocess.run(args, env=env, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            backup_parent = target / ".local/state/dotfiles-backups"
            original_backup = next(backup_parent.iterdir())
            for wallpaper in wallpapers:
                self.assertEqual((original_backup / "walls" / wallpaper).read_bytes(),
                                 b"original " + wallpaper.encode())
                self.assertEqual((target / "walls" / wallpaper).read_bytes(),
                                 (REPO / "walls" / wallpaper).read_bytes())
            (target / ".vimrc").write_text("edited Vim config B")
            second = subprocess.run(args, env=env, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            backups = list(backup_parent.iterdir())
            self.assertEqual(len(backups), 2)
            self.assertEqual((original_backup / ".vimrc").read_text(), "original Vim config A")
            second_backup = next(path for path in backups if path != original_backup)
            self.assertEqual((second_backup / ".vimrc").read_text(), "edited Vim config B")
            self.assertTrue(os.access(target / ".local/bin/screenshot", os.X_OK))


if __name__ == "__main__":
    unittest.main()
