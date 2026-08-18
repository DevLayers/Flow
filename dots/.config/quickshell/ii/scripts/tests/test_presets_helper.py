#!/usr/bin/env python3
"""Tests for preset sanitization and expansion in presets_helper.py."""

import copy
import os
import sys
import unittest

# Add scripts directory to sys.path
SCRIPTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import presets_helper


class TestPresetsHelper(unittest.TestCase):
    def setUp(self):
        self.home_dir = "/home/testuser"

    def test_user_data_removal(self):
        """Teste 1: Confirm that googleDrive and search.aliases are removed, while visual search settings remain."""
        input_data = {
            "search": {
                "enableSystemControls": True,
                "enableMathPreview": True,
                "engineBaseUrl": "https://www.google.com/search?q=",
                "aliases": [
                    {"trigger": "g", "command": "google"},
                    {"trigger": "y", "command": "youtube"}
                ]
            },
            "googleDrive": {
                "enabled": True,
                "backupFolders": ["/home/testuser/Documents"],
                "syncInterval": "1d",
                "lastSyncTime": "2026-08-18T00:00:00Z"
            },
            "bar": {
                "height": 48
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        self.assertNotIn("googleDrive", sanitized)
        self.assertIn("search", sanitized)
        self.assertNotIn("aliases", sanitized["search"])
        self.assertTrue(sanitized["search"]["enableSystemControls"])
        self.assertTrue(sanitized["search"]["enableMathPreview"])
        self.assertEqual(sanitized["bar"]["height"], 48)

    def test_secrets_removal(self):
        """Teste 2: Verify recursive removal of secrets with varied casing/naming conventions."""
        input_data = {
            "services": {
                "gmail": {
                    "client_id": "test_client_id",
                    "client_secret": "super_secret_client_secret",
                    "refresh_token": "ya29.secret_refresh_token",
                    "accessToken": "secret_access_token"
                },
                "ticktick": {
                    "ticktick_client_id": "tick_id",
                    "ticktick_client_secret": "tick_secret",
                    "ticktick_access_token": "tick_token"
                },
                "ai": {
                    "geminiApiKey": "AIzaSySecretApiKey",
                    "provider": "google",
                    "model": "gemini-2.5-flash"
                }
            },
            "auth": {
                "password": "mypassword123",
                "passwd": "otherpasswd",
                "cookie": "session=abc123xyz"
            },
            "appearance": {
                "palette": "vynx"
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        # Check that secret keys are removed
        services = sanitized.get("services", {})
        gmail = services.get("gmail", {})
        self.assertNotIn("client_secret", gmail)
        self.assertNotIn("refresh_token", gmail)
        self.assertNotIn("accessToken", gmail)

        ticktick = services.get("ticktick", {})
        self.assertNotIn("ticktick_client_secret", ticktick)
        self.assertNotIn("ticktick_access_token", ticktick)

        ai = services.get("ai", {})
        self.assertNotIn("geminiApiKey", ai)
        self.assertEqual(ai.get("provider"), "google")
        self.assertEqual(ai.get("model"), "gemini-2.5-flash")

        auth = sanitized.get("auth", {})
        self.assertNotIn("password", auth)
        self.assertNotIn("passwd", auth)
        self.assertNotIn("cookie", auth)

        self.assertEqual(sanitized["appearance"]["palette"], "vynx")

    def test_foreign_home_sanitization(self):
        """Teste 3: Confirm foreign /home/otheruser and /var/home/otheruser are transformed to $HOME."""
        input_data = {
            "background": {
                "wallpaperPath": "/home/otheruser/Pictures/wall.jpg"
            },
            "profile": {
                "avatar": "/var/home/silverblueuser/avatar.png"
            },
            "local": {
                "customPath": "/home/testuser/MyFiles/doc.pdf"
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        self.assertEqual(sanitized["background"]["wallpaperPath"], "$HOME/Pictures/wall.jpg")
        self.assertEqual(sanitized["profile"]["avatar"], "$HOME/avatar.png")
        self.assertEqual(sanitized["local"]["customPath"], "$HOME/MyFiles/doc.pdf")

    def test_known_paths_normalization(self):
        """Teste 4: Normalize Screen Record, Screen Snip, and LocalSend paths."""
        input_data = {
            "screenRecord": {
                "savePath": "/home/otheruser/Videos/CustomRecordings"
            },
            "screenSnip": {
                "savePath": "/home/otheruser/Pictures/Screenshots"
            },
            "localsend": {
                "downloadPath": "/opt/custom/localsend"
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        self.assertEqual(sanitized["screenRecord"]["savePath"], "$HOME/Videos/CustomRecordings")
        self.assertEqual(sanitized["screenSnip"]["savePath"], "$HOME/Pictures/Screenshots")
        # /opt/custom/localsend is absolute outside /home, so fallback $HOME/Downloads is used
        self.assertEqual(sanitized["localsend"]["downloadPath"], "$HOME/Downloads")

    def test_monitors_reset(self):
        """Teste 5: Ensure machine-specific monitor connector names are reset."""
        input_data = {
            "background": {
                "widgets": {
                    "showOnlyOnSingleMonitor": True,
                    "targetMonitor": "DP-2"
                }
            },
            "bar": {
                "onlyShowOnSingleMonitor": True,
                "singleMonitorName": "HDMI-A-1",
                "screenList": ["DP-1", "DP-2"],
                "floatingNotch": {
                    "onlyShowOnSingleMonitor": True,
                    "singleMonitorName": "eDP-1"
                }
            },
            "interactions": {
                "touchGestures": {
                    "targetMonitor": "DP-3"
                }
            },
            "notifications": {
                "monitor": {
                    "enable": True,
                    "name": "HDMI-A-2"
                }
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        self.assertFalse(sanitized["background"]["widgets"]["showOnlyOnSingleMonitor"])
        self.assertEqual(sanitized["background"]["widgets"]["targetMonitor"], "")
        self.assertFalse(sanitized["bar"]["onlyShowOnSingleMonitor"])
        self.assertEqual(sanitized["bar"]["singleMonitorName"], "")
        self.assertEqual(sanitized["bar"]["screenList"], [])
        self.assertFalse(sanitized["bar"]["floatingNotch"]["onlyShowOnSingleMonitor"])
        self.assertEqual(sanitized["bar"]["floatingNotch"]["singleMonitorName"], "")
        self.assertEqual(sanitized["interactions"]["touchGestures"]["targetMonitor"], "auto")
        self.assertFalse(sanitized["notifications"]["monitor"]["enable"])
        self.assertEqual(sanitized["notifications"]["monitor"]["name"], "")

    def test_visual_values_preserved(self):
        """Teste 6: Verify legitimate visual styling options are preserved intact."""
        input_data = {
            "appearance": {
                "rounding": {
                    "normal": 17,
                    "large": 23,
                    "windowRounding": 16
                },
                "transparency": {
                    "enable": True,
                    "opacity": 0.85
                },
                "animations": {
                    "enable": True,
                    "speed": 1.0
                }
            },
            "bar": {
                "height": 42,
                "position": "top"
            }
        }
        sanitized = presets_helper.sanitize_data(copy.deepcopy(input_data), self.home_dir)
        self.assertEqual(sanitized["appearance"]["rounding"]["normal"], 17)
        self.assertEqual(sanitized["appearance"]["rounding"]["windowRounding"], 16)
        self.assertTrue(sanitized["appearance"]["transparency"]["enable"])
        self.assertEqual(sanitized["appearance"]["transparency"]["opacity"], 0.85)
        self.assertEqual(sanitized["bar"]["height"], 42)
        self.assertEqual(sanitized["bar"]["position"], "top")


if __name__ == "__main__":
    unittest.main()
