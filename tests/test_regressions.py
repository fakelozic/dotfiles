"""Run with: python3 -m unittest discover -s tests -v."""
import json
import os
import shutil
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

    def test_saved_screenshots_go_to_the_screenshots_directory(self):
        for mode in ("area", "output"):
            with self.subTest(mode=mode):
                home = self.root / f"home-{mode}"
                home.mkdir()
                result, calls = self.run_capture(mode, HOME=str(home))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("wl-copy", [call["command"] for call in calls])
                saved = list(home.rglob("*.png"))
                self.assertEqual(len(saved), 1)
                self.assertEqual(saved[0].parent, home / "Pictures/Screenshots")
                self.assertEqual(saved[0].read_bytes(), b"PNG fixture")


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
            wallpapers = ("burning-earth.png", "wall.png", "wall-gruvbox.png", "wallg.png", "wallg-gruvbox.png")
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
            self.assertIn('source "$HOME/.zshrc.local"', (target / ".zshrc").read_text())
            self.assertEqual((target / ".config/nvim/.stylua.toml").read_bytes(),
                             (REPO / "nvim/.stylua.toml").read_bytes())


@unittest.skipUnless(Path("/etc/fedora-release").exists() and os.geteuid() != 0,
                     "Installer smoke test requires Fedora and a non-root user")
class FirefoxThemeTests(unittest.TestCase):
    # The layout Firefox writes: the [Install...] default is not the Default=1 profile.
    profiles_ini = """[Profile1]
Name=default
IsRelative=1
Path=wrt3lm61.default
Default=1

[Profile0]
Name=default-release
IsRelative=1
Path=3b5pojxm.default-release

[General]
StartWithLastProfile=1
Version=2

[Install11457493C5A56847]
Default=3b5pojxm.default-release
Locked=1
"""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-firefox-test-")
        self.addCleanup(self.temp.cleanup)
        self.target = Path(self.temp.name)

    def make_profiles(self, root):
        root = self.target / root
        for name in ("wrt3lm61.default", "3b5pojxm.default-release"):
            (root / name).mkdir(parents=True)
        (root / "profiles.ini").write_text(self.profiles_ini)
        return root / "3b5pojxm.default-release", root / "wrt3lm61.default"

    def run_install(self):
        env = os.environ.copy()
        env["DOTFILES_TARGET_HOME"] = str(self.target)
        return subprocess.run(["bash", str(REPO / "install.sh"), "--files-only", "--skip-nvidia",
                               "--skip-shell-change", "--skip-reload"],
                              env=env, capture_output=True, text=True)

    def test_theme_reaches_the_default_profile_in_either_location(self):
        for root in (".mozilla/firefox", ".config/mozilla/firefox"):
            with self.subTest(root=root):
                self.setUp()
                profile, other = self.make_profiles(root)
                result = self.run_install()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((profile / "chrome/userChrome.css").read_bytes(),
                                 (REPO / "firefox/userChrome.css").read_bytes())
                self.assertIn("toolkit.legacyUserProfileCustomizations.stylesheets",
                              (profile / "user.js").read_text())
                self.assertEqual(list(other.iterdir()), [])

    def test_existing_firefox_files_are_backed_up(self):
        profile, _ = self.make_profiles(".config/mozilla/firefox")
        (profile / "chrome").mkdir()
        (profile / "chrome/userChrome.css").write_text("original chrome")
        (profile / "user.js").write_text("original prefs")
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        backup = next((self.target / ".local/state/dotfiles-backups").iterdir())
        backed_up = backup / profile.relative_to(self.target)
        self.assertEqual((backed_up / "chrome/userChrome.css").read_text(), "original chrome")
        self.assertEqual((backed_up / "user.js").read_text(), "original prefs")
        self.assertNotEqual((profile / "user.js").read_text(), "original prefs")

    def test_without_a_profile_the_theme_is_skipped(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("skipping the Firefox theme", result.stdout)
        self.assertEqual(list(self.target.rglob("userChrome.css")), [])


@unittest.skipUnless(Path("/etc/fedora-release").exists() and os.geteuid() != 0,
                     "Installer smoke test requires Fedora and a non-root user")
class SessionSetupTests(unittest.TestCase):
    """Runs the full installer path with every system-changing command mocked."""

    services = "cliphist-text.service cliphist-image.service"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-session-test-")
        self.addCleanup(self.temp.cleanup)
        self.target = Path(self.temp.name)
        self.bin = self.target / "mock-bin"
        self.bin.mkdir()
        self.log = self.target / "calls.log"
        record = '#!/bin/sh\nprintf \'%s\\n\' "$(basename "$0") $*" >> "$MOCK_LOG"\n'
        for tool in ("sudo", "curl", "sha256sum", "tar", "fc-cache", "git", "gsettings",
                     "cc", "node", "npm", "make", "unzip"):
            executable(self.bin / tool, record)
        executable(self.bin / "systemctl", record +
                   'case " $* " in *" is-active "*) exit "${MOCK_ACTIVE_STATUS:-0}" ;; esac\n')
        executable(self.bin / "nvim", "#!/bin/sh\necho 'NVIM v0.12.0'\n")
        executable(self.bin / "tree-sitter", "#!/bin/sh\necho 'tree-sitter 0.26.1'\n")

    def run_install(self, **overrides):
        env = os.environ.copy()
        env.pop("SWAYSOCK", None)
        env.update(DOTFILES_TARGET_HOME=str(self.target), MOCK_LOG=str(self.log),
                   PATH=str(self.bin) + ":" + env["PATH"], **overrides)
        result = subprocess.run(["bash", str(REPO / "install.sh"), "--skip-nvidia",
                                 "--skip-shell-change", "--skip-reload"],
                                env=env, capture_output=True, text=True)
        return result, self.log.read_text().splitlines()

    def test_outside_sway_services_are_enabled_but_not_started(self):
        result, calls = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("systemctl --user enable " + self.services, calls)
        self.assertFalse([call for call in calls if " start " in call or " is-active " in call])
        self.assertIn("next Sway login", result.stdout)
        self.assertIn("gsettings set org.gnome.desktop.interface color-scheme prefer-dark", calls)

    def test_swaync_is_disabled_and_masked_so_quickshell_gets_notifications(self):
        result, calls = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("systemctl --user disable --now swaync.service", calls)
        self.assertIn("systemctl --user mask swaync.service", calls)

    def test_inside_sway_services_are_started_and_verified(self):
        result, calls = self.run_install(SWAYSOCK="/run/user/0/sway-ipc.sock")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("systemctl --user enable " + self.services, calls)
        self.assertIn("systemctl --user start " + self.services, calls)
        self.assertLess(calls.index("systemctl --user stop dunst.service mako.service"),
                        calls.index("systemctl --user start " + self.services))

    def test_inside_sway_a_service_that_stays_down_is_reported(self):
        result, _ = self.run_install(SWAYSOCK="/run/user/0/sway-ipc.sock",
                                     MOCK_ACTIVE_STATUS="3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Service failed to start: cliphist-text.service", result.stderr)


def run_js(library, expression):
    """Evaluates expression with a Quickshell .pragma library JS file loaded."""
    script = """
const fs = require("fs"), vm = require("vm");
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8").replace(/^\\.pragma library/m, ""), context);
context.input = fs.readFileSync(0, "utf8");
process.stdout.write(JSON.stringify(vm.runInContext(process.argv[2], context)));
"""
    sway = "\n".join("#@file " + str(path) + "\n" + path.read_text()
                     for path in [REPO / "sway/config", *sorted((REPO / "sway/config.d").glob("*.conf"))])
    result = subprocess.run(["node", "-e", script, str(REPO / "quickshell" / library), expression],
                            input=sway, capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


@unittest.skipUnless(shutil.which("node"), "Node.js runs the Quickshell search logic")
class QuickshellLogicTests(unittest.TestCase):
    def test_launcher_ranks_prefix_then_word_then_initials(self):
        ranks = run_js("Search.js", """[
            rank("Firefox", [], "fire"), rank("GNOME Boxes", [], "box"),
            rank("Visual Studio Code", [], "vsc"), rank("Thunderbird", [], "derb"),
            rank("Files", ["file manager"], "manager"), rank("LibreOffice Writer", [], "lbw"),
            rank("Firefox", [], "zzz"), rank("Firefox", ["web browser"], "web fire")]""")
        self.assertEqual(ranks, [0, 1, 2, 3, 4, 5, -1, 4])

    def test_calculator_handles_precedence_and_rejects_non_arithmetic(self):
        values = run_js("Search.js", """[
            calculate("2+3*4"), calculate("(2+3)*4"), calculate("2^3^2"), calculate("-3 + 5"),
            calculate("10 % 4"), calculate("6 ÷ 4"), calculate("1,000 * 2"),
            calculate("42"), calculate("-5"), calculate("1/0"), calculate("2 +"), calculate("firefox"),
            formatNumber(0.1 + 0.2), formatNumber(1 / 3)]""")
        self.assertEqual(values, [14, 20, 512, 2, 2, 1.5, 2000,
                                  None, None, None, None, None, "0.3", "0.333333333333"])

    def test_every_sway_binding_gets_keys_and_a_description(self):
        bindings = run_js("Bindings.js", "parse(input)")
        by_keys = {" ".join(binding["keys"]): binding for binding in bindings}
        self.assertEqual(by_keys["Super D"]["description"], "Search apps and commands")
        self.assertEqual(by_keys["Super Tab"]["description"], "Switch window")
        self.assertEqual(by_keys["Super Shift V"]["description"], "Clipboard history")
        self.assertEqual(by_keys["Super Enter"]["description"], "Start a terminal")
        self.assertEqual(by_keys["Super Shift 0"]["description"], "Move window to workspace 10")
        # Keys inside a mode show the key that enters it first.
        self.assertEqual(by_keys["Super Z then C"]["section"], "Special mode")
        self.assertEqual(by_keys["Super R then H"]["description"], "Shrink width")
        # Commands keep their variables filled in, ready for swaymsg.
        self.assertTrue(by_keys["Super Tab"]["command"].startswith("exec qs ipc call windows next || rofi"))
        for binding in bindings:
            self.assertTrue(binding["description"], binding)
            self.assertNotIn("$", " ".join(binding["keys"]), binding)

    def test_filter_needs_every_word(self):
        found = run_js("Bindings.js", "filter(parse(input), 'move workspace 3').map(b => b.keys.join(' '))")
        self.assertEqual(found, ["Super Shift 3"])


if __name__ == "__main__":
    unittest.main()
