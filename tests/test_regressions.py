"""Run with: python3 -m unittest discover -s tests -v."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
ON_FEDORA = Path("/etc/fedora-release").exists() and os.geteuid() != 0
PAPIRUS = Path("/usr/share/icons/Papirus/48x48/places/folder-bluegrey.svg")


def executable(path, body):
    path.write_text(body)
    path.chmod(0o755)


def load_shortcuts():
    spec = importlib.util.spec_from_file_location("shortcuts", REPO / "kde/shortcuts.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


@unittest.skipUnless(ON_FEDORA, "Installer smoke test requires Fedora and a non-root user")
class InstallTests(unittest.TestCase):
    def install(self, target, *extra, env_extra=None):
        mock = target / "mock-bin"
        mock.mkdir(exist_ok=True)
        executable(mock / "date", "#!/bin/sh\nprintf '%s\\n' '20260930-120000'\n")
        env = os.environ.copy()
        env.update(DOTFILES_TARGET_HOME=str(target), PATH=str(mock) + ":" + env["PATH"])
        env.update(env_extra or {})
        args = ["bash", str(REPO / "install.sh"), "--files-only", "--skip-nvidia",
                "--skip-shell-change", "--skip-reload", *extra]
        return subprocess.run(args, env=env, capture_output=True, text=True)

    def test_files_land_and_backups_survive_same_second_installs(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-home with spaces-") as name:
            target = Path(name)
            (target / ".vimrc").write_text("original Vim config A")
            (target / ".config").mkdir()
            (target / ".config/kdeglobals").write_text("[General]\nfont=original\n")
            first = self.install(target)
            self.assertEqual(first.returncode, 0, first.stderr)
            backup_parent = target / ".local/state/dotfiles-backups"
            original_backup = next(backup_parent.iterdir())
            self.assertEqual((original_backup / ".vimrc").read_text(), "original Vim config A")
            self.assertIn("font=original", (original_backup / ".config/kdeglobals").read_text())

            # Files reach their places.
            self.assertIn('source "$HOME/.zshrc.local"', (target / ".zshrc").read_text())
            self.assertEqual((target / ".config/nvim/.stylua.toml").read_bytes(),
                             (REPO / "nvim/.stylua.toml").read_bytes())
            self.assertEqual((target / "walls/cat-wall.jpeg").read_bytes(),
                             (REPO / "walls/cat-wall.jpeg").read_bytes())
            for widget in ("org.fak3.desktops", "org.fak3.ramindicator"):
                self.assertTrue((target / ".local/share/plasma/plasmoids" / widget / "metadata.json").is_file())
            self.assertTrue((target / ".local/share/color-schemes/BreezeCharcoal.colors").is_file())
            # Ghostty gets the shader as a full path into the target home.
            ghostty = (target / ".config/ghostty/config.ghostty").read_text()
            self.assertIn(f"custom-shader = {target}/.config/ghostty/shaders/cursor_trail.glsl", ghostty)
            self.assertTrue((target / ".config/ghostty/shaders/cursor_trail.glsl").is_file())
            for name in ("config.jsonc", "fedora.txt"):
                self.assertEqual((target / ".config/fastfetch" / name).read_bytes(),
                                 (REPO / "fastfetch" / name).read_bytes())

            (target / ".vimrc").write_text("edited Vim config B")
            second = self.install(target)
            self.assertEqual(second.returncode, 0, second.stderr)
            backups = list(backup_parent.iterdir())
            self.assertEqual(len(backups), 2)
            self.assertEqual((original_backup / ".vimrc").read_text(), "original Vim config A")
            second_backup = next(path for path in backups if path != original_backup)
            self.assertEqual((second_backup / ".vimrc").read_text(), "edited Vim config B")

    def test_system_tweaks_are_installed_once_and_originals_kept(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-system-") as name:
            target = Path(name) / "home"
            target.mkdir()
            root = Path(name) / "root"
            (root / "etc/dnf").mkdir(parents=True)
            (root / "etc/updatedb.conf").write_text('PRUNEPATHS = "/tmp"\n')
            (root / "etc/dnf/dnf.conf").write_text("[main]\ngpgcheck=True\n")
            (root / "etc/sysctl.d").mkdir()
            (root / "etc/sysctl.d/99-desktop-memory.conf").write_text("vm.swappiness = 60\n")
            (root / "etc/plasmalogin.conf").write_text(
                "[Greeter][Wallpaper][org.kde.image][General]\nImage=file:///old.png\n")
            mock = target / "mock-bin"
            mock.mkdir()
            # sudo runs the command without privileges; everything stays under root.
            executable(mock / "sudo", '#!/bin/sh\nexec "$@"\n')
            for _ in range(2):
                result = self.install(target, "--system", env_extra={"DOTFILES_SYSTEM_ROOT": str(root)})
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "etc/sysctl.d/99-desktop-memory.conf").read_bytes(),
                             (REPO / "system/sysctl.d/99-desktop-memory.conf").read_bytes())
            self.assertEqual((root / "etc/sysctl.d/99-desktop-memory.conf.bak-20260930-120000").read_text(),
                             "vm.swappiness = 60\n")
            self.assertTrue((root / "etc/systemd/zram-generator.conf").is_file())
            self.assertTrue((root / "etc/tmpfiles.d/mglru-min-ttl.conf").is_file())
            self.assertEqual((root / "etc/updatedb.conf").read_text().count("PRUNENAMES"), 1)
            self.assertEqual((root / "etc/dnf/dnf.conf").read_text().count("max_parallel_downloads"), 1)
            login = (root / "etc/plasmalogin.conf").read_text()
            self.assertIn("Image=file:///var/lib/plasmalogin/wallpapers/cat-wall.jpeg", login)
            self.assertNotIn("old.png", login)
            self.assertTrue((root / "var/lib/plasmalogin/wallpapers/cat-wall.jpeg").is_file())


@unittest.skipUnless(PAPIRUS.exists(), "needs papirus-icon-theme")
class FolderIconTests(unittest.TestCase):
    def test_theme_has_real_bluegrey_files(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-icons-") as name:
            result = subprocess.run([str(REPO / "kde/build-folder-icons"), "bluegrey", name],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            theme = Path(name) / "Papirus-Dark-Bluegrey"
            self.assertIn("Inherits=Papirus-Dark,", (theme / "index.theme").read_text())
            files = [p for p in theme.rglob("*.svg")]
            self.assertGreater(len(files), 100)
            # Copies, not links, so Flatpak apps can read them.
            self.assertFalse(any(p.is_symlink() for p in theme.rglob("*")))
            self.assertEqual((theme / "48x48/places/folder.svg").read_bytes(), PAPIRUS.read_bytes())
            self.assertTrue((theme / "48x48@2x/places/folder.svg").is_file())

    def test_unknown_colour_is_refused(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-icons-") as name:
            result = subprocess.run([str(REPO / "kde/build-folder-icons"), "nosuchcolour", name],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(Path(name).iterdir()), [])


class ShortcutTests(unittest.TestCase):
    def test_key_codes_match_qt(self):
        s = load_shortcuts()
        meta, shift, ctrl, alt = s.META, s.SHIFT, s.CTRL, s.ALT
        self.assertEqual(s.key_code("Meta+Return"), meta | 0x01000004)
        self.assertEqual(s.key_code("Meta+Shift+Q"), meta | shift | ord("Q"))
        self.assertEqual(s.key_code("Meta+f"), meta | ord("F"))
        self.assertEqual(s.key_code("Meta+!"), meta | ord("!"))
        self.assertEqual(s.key_code("Ctrl+F4"), ctrl | 0x01000033)
        self.assertEqual(s.key_code("Alt+F4"), alt | 0x01000033)
        with self.assertRaises(ValueError):
            s.key_code("Meta+Nope")

    def test_every_shortcut_parses_and_desktops_cover_one_to_six(self):
        s = load_shortcuts()
        for *_, keys in s.SHORTCUTS:
            for key in keys:
                s.key_code(key)
        actions = {action for _, action, *_ in s.SHORTCUTS}
        for n in range(1, 7):
            self.assertIn(f"Switch to Desktop {n}", actions)
            self.assertIn(f"Window to Desktop {n}", actions)


if __name__ == "__main__":
    unittest.main()
