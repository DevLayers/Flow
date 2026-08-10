#!/usr/bin/env python3
"""Regression tests for the Google Drive backup command boundary."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest


GDRIVE_DIR = Path(__file__).resolve().parents[1]
SETUP_SCRIPT = GDRIVE_DIR / "setup_rclone.py"
SYNC_SCRIPT = GDRIVE_DIR / "sync.sh"


class FakeRcloneTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.calls_path = self.root / "calls.jsonl"
        self.env = os.environ.copy()
        self.env["PATH"] = f"{self.bin_dir}:{self.env.get('PATH', '')}"
        self.env["FAKE_RCLONE_CALLS"] = str(self.calls_path)
        self.env["XDG_STATE_HOME"] = str(self.root / "state")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def install_rclone(self, body: str) -> None:
        executable = self.bin_dir / "rclone"
        executable.write_text(textwrap.dedent(body).lstrip(), encoding="utf-8")
        executable.chmod(0o755)

    def calls(self) -> list[list[str]]:
        if not self.calls_path.exists():
            return []
        return [json.loads(line) for line in self.calls_path.read_text(encoding="utf-8").splitlines()]


class SetupRcloneTests(FakeRcloneTestCase):
    def test_authorize_uses_the_same_oauth_client_as_the_remote(self) -> None:
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import json, os, sys
            with open(os.environ["FAKE_RCLONE_CALLS"], "a", encoding="utf-8") as stream:
                stream.write(json.dumps(sys.argv[1:]) + "\\n")
            if sys.argv[1] == "authorize":
                print(json.dumps({"access_token": "access", "refresh_token": "refresh"}))
            sys.exit(0)
            """
        )

        result = subprocess.run(
            [sys.executable, str(SETUP_SCRIPT), "client-id", "client-secret"],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        authorize_calls = [call for call in self.calls() if call and call[0] == "authorize"]
        self.assertEqual(authorize_calls, [["authorize", "drive", "client-id", "client-secret"]])

    def test_failed_authorization_does_not_modify_an_existing_remote(self) -> None:
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import json, os, sys
            with open(os.environ["FAKE_RCLONE_CALLS"], "a", encoding="utf-8") as stream:
                stream.write(json.dumps(sys.argv[1:]) + "\\n")
            if sys.argv[1] == "authorize":
                print("authorization cancelled", file=sys.stderr)
                sys.exit(1)
            sys.exit(0)
            """
        )

        result = subprocess.run(
            [sys.executable, str(SETUP_SCRIPT), "client-id", "client-secret"],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        mutating_calls = [call for call in self.calls() if call and call[:2] in (["config", "create"], ["config", "update"])]
        self.assertEqual(mutating_calls, [])


class SyncScriptTests(FakeRcloneTestCase):
    def test_sync_reports_the_underlying_rclone_error(self) -> None:
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import sys
            print("CRITICAL: couldn't fetch token: unauthorized_client", file=sys.stderr)
            sys.exit(7)
            """
        )
        source = self.root / "source"
        source.mkdir()

        result = subprocess.run(
            [
                "bash", str(SYNC_SCRIPT),
                "--base-path", "test_backups",
                "--bandwidth-kbps", "0",
                "--keep-versions", "0",
                "--delete-orphans", "false",
                "--folder", str(source),
            ],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

        events = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unauthorized_client", events[-1]["error"])

    def test_sync_uses_rate_limited_stats_instead_of_progress_redraws(self) -> None:
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import json, os, sys
            with open(os.environ["FAKE_RCLONE_CALLS"], "a", encoding="utf-8") as stream:
                stream.write(json.dumps(sys.argv[1:]) + "\\n")
            if sys.argv[1] == "size":
                print('{"count": 1, "bytes": 12}')
            else:
                print("2026/08/08 12:00:00 - 12 B / 12 B, 100%, 12 B/s, ETA 0s (xfr#1/1)")
            sys.exit(0)
            """
        )
        source = self.root / "source"
        source.mkdir()

        result = subprocess.run(
            [
                "bash", str(SYNC_SCRIPT),
                "--base-path", "test_backups",
                "--bandwidth-kbps", "0",
                "--keep-versions", "0",
                "--delete-orphans", "false",
                "--folder", str(source),
            ],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        copy_call = next(call for call in self.calls() if call and call[0] == "copy")
        self.assertNotIn("--progress", copy_call)
        self.assertIn("--stats", copy_call)
        self.assertEqual(copy_call[copy_call.index("--stats") + 1], "2s")
        self.assertEqual(copy_call[copy_call.index("--stats-log-level") + 1], "NOTICE")

    def test_sync_forwards_max_age_to_rclone(self) -> None:
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import json, os, sys
            with open(os.environ["FAKE_RCLONE_CALLS"], "a", encoding="utf-8") as stream:
                stream.write(json.dumps(sys.argv[1:]) + "\\n")
            if sys.argv[1] == "size":
                print('{"count": 1, "bytes": 12}')
            else:
                print("2026/08/08 12:00:00 - 12 B / 12 B, 100%, 12 B/s, ETA 0s (xfr#1/1)")
            sys.exit(0)
            """
        )
        source = self.root / "source"
        source.mkdir()

        result = subprocess.run(
            [
                "bash", str(SYNC_SCRIPT),
                "--base-path", "test_backups",
                "--bandwidth-kbps", "0",
                "--keep-versions", "0",
                "--delete-orphans", "false",
                "--max-age", "2026-08-09T20:15:00Z",
                "--folder", str(source),
            ],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        copy_call = next(call for call in self.calls() if call and call[0] == "copy")
        self.assertIn("--max-age", copy_call)
        self.assertEqual(copy_call[copy_call.index("--max-age") + 1], "2026-08-09T20:15:00Z")

    def test_terminating_sync_also_terminates_rclone_child(self) -> None:
        child_pid_path = self.root / "child.pid"
        term_marker_path = self.root / "child.terminated"
        self.env["FAKE_CHILD_PID"] = str(child_pid_path)
        self.env["FAKE_TERM_MARKER"] = str(term_marker_path)
        self.install_rclone(
            """
            #!/usr/bin/env python3
            import os, signal, sys, time
            with open(os.environ["FAKE_CHILD_PID"], "w", encoding="utf-8") as stream:
                stream.write(str(os.getpid()))
            def stop(signum, frame):
                with open(os.environ["FAKE_TERM_MARKER"], "w", encoding="utf-8") as stream:
                    stream.write(str(signum))
                sys.exit(128 + signum)
            signal.signal(signal.SIGTERM, stop)
            signal.signal(signal.SIGINT, stop)
            while True:
                time.sleep(0.05)
            """
        )
        source = self.root / "source"
        source.mkdir()
        process = subprocess.Popen(
            [
                "bash", str(SYNC_SCRIPT),
                "--base-path", "test_backups",
                "--bandwidth-kbps", "0",
                "--keep-versions", "0",
                "--delete-orphans", "false",
                "--folder", str(source),
            ],
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=self.env,
        )
        child_pid = 0
        try:
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline and not child_pid_path.exists():
                time.sleep(0.02)
            self.assertTrue(child_pid_path.exists(), "fake rclone did not start")
            child_pid = int(child_pid_path.read_text(encoding="utf-8"))
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
            deadline = time.monotonic() + 1
            while time.monotonic() < deadline and not term_marker_path.exists():
                time.sleep(0.02)
            self.assertTrue(term_marker_path.exists(), "rclone child did not receive SIGTERM")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=2)
            if child_pid and not term_marker_path.exists():
                try:
                    os.kill(child_pid, 9)
                except ProcessLookupError:
                    pass


class QmlIntegrationTests(unittest.TestCase):
    def test_service_is_instantiated_by_the_shell(self) -> None:
        shell = (GDRIVE_DIR.parents[1] / "shell.qml").read_text(encoding="utf-8")
        self.assertIn("GoogleDriveService.configured", shell)

    def test_requested_backup_intervals_are_wired_end_to_end(self) -> None:
        root = GDRIVE_DIR.parents[1]
        service = (root / "services" / "GoogleDriveService.qml").read_text(encoding="utf-8")
        settings = (root / "modules" / "settings" / "configs" / "TasksAccountsConfig.qml").read_text(encoding="utf-8")
        config = (root / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
        expected = {
            "1h": "3600000",
            "4h": "14400000",
            "1d": "86400000",
            "2d": "172800000",
            "3d": "259200000",
        }

        for value, milliseconds in expected.items():
            self.assertIn(f'"{value}": {milliseconds}', service)
            self.assertIn(f'value: "{value}"', settings)
        self.assertIn('property string syncInterval: "3d"', config)

    def test_activity_history_is_durable_and_has_period_views(self) -> None:
        root = GDRIVE_DIR.parents[1]
        service = (root / "services" / "GoogleDriveService.qml").read_text(encoding="utf-8")
        settings = (root / "modules" / "settings" / "configs" / "TasksAccountsConfig.qml").read_text(encoding="utf-8")
        config = (root / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")

        self.assertIn("property list<var> syncHistory: []", config)
        self.assertIn("options.syncHistory = history", service)
        self.assertIn('"transferCount": 1', service)
        self.assertIn('key: "day"', settings)
        self.assertIn('key: "week"', settings)
        self.assertIn('key: "month"', settings)
        self.assertIn("activityMetricIndex", settings)
        self.assertIn("activityMetrics", settings)
        self.assertIn("activityDataValues", settings)
        self.assertIn("activityTransferValues", settings)
        self.assertIn("Backups completed", settings)
        self.assertEqual(settings.count("UsageColumnChart {"), 1)
        self.assertIn("return rows.slice(0, 4)", settings)
        self.assertIn('"durationSeconds": durationSeconds', service)
        self.assertIn('"averageBytesPerSecond": averageBytesPerSecond', service)
        self.assertIn('property real driveBackupUsageMb: 0.0', config)
        self.assertIn('root.driveBackupUsageMb = Math.max(0, Number(options.driveBackupUsageMb || 0));', service)
        self.assertIn('popupWidth: 184', settings)
        self.assertIn('iconOnly: true', settings)
        self.assertIn('text: Translation.tr("Backup footprint")', settings)
        self.assertIn('visible: root.entryDurationSeconds(modelData) > 0', settings)

    def test_exclude_patterns_accept_user_input(self) -> None:
        settings = (GDRIVE_DIR.parents[1] / "modules" / "settings" / "configs" / "TasksAccountsConfig.qml").read_text(encoding="utf-8")

        self.assertIn("excludePatternDraft", settings)
        self.assertIn("addExcludePattern(pattern: string)", settings)
        self.assertIn("textField.onTextChanged: root.excludePatternDraft = textField.text", settings)
        self.assertNotIn('values.push("*.cache")', settings)
        self.assertIn("**/*.log", settings)

    def test_searchable_drive_bindings_use_global_config_scope(self) -> None:
        settings = (GDRIVE_DIR.parents[1] / "modules" / "settings" / "configs" / "TasksAccountsConfig.qml").read_text(encoding="utf-8")

        self.assertIn("checked: Config.options.googleDrive.enabled", settings)
        self.assertNotIn("checked: driveOptions.enabled", settings)

    def test_dashboard_visual_components_are_responsive_and_token_driven(self) -> None:
        root = GDRIVE_DIR.parents[1]
        heatmap = (root / "modules" / "ii" / "usage" / "UsageActivityHeatmap.qml").read_text(encoding="utf-8")
        combo = (root / "modules" / "common" / "widgets" / "StyledComboBox.qml").read_text(encoding="utf-8")

        self.assertIn("resolvedCellWidth", heatmap)
        self.assertIn("resolvedCellHeight", heatmap)
        self.assertIn("resolvedCellSize", heatmap)
        self.assertIn("property real popupWidth: 0", combo)
        self.assertIn("itemDelegate.hovered && root.popup.visible", combo)

    def test_only_modified_since_last_sync_option_is_wired_end_to_end(self) -> None:
        root = GDRIVE_DIR.parents[1]
        config = (root / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
        service = (root / "services" / "GoogleDriveService.qml").read_text(encoding="utf-8")
        sync_sh = (root / "scripts" / "gdrive" / "sync.sh").read_text(encoding="utf-8")
        advanced_settings = (root / "modules" / "settings" / "configs" / "widgets" / "AdvancedDriveConfig.qml").read_text(encoding="utf-8")

        self.assertIn("property bool onlyModifiedSinceLastSync: false", config)
        self.assertIn('command.push("--max-age", previousSyncTime);', service)
        self.assertIn("--max-age)", sync_sh)
        self.assertIn('command+=(--max-age "$max_age")', sync_sh)
        self.assertIn("checked: Config.options.googleDrive.onlyModifiedSinceLastSync", advanced_settings)


if __name__ == "__main__":
    unittest.main()
