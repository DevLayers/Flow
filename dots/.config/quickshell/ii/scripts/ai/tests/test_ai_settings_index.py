#!/usr/bin/env python3
"""Contract tests for the generated Settings index.

The QML Settings pages already describe every control, but parsing them in the
shell on every opening is expensive and loses the Config key.  These fixtures
exercise the portable generator directly so its result stays usable by both
the overview and the AI tool adapters without a running Quickshell instance.
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_settings_index  # noqa: E402


REGISTRY = '''
pragma Singleton
Singleton {
    readonly property var pages: [
        {
            "id": "power",
            "name": "Power & Battery",
            "icon": "battery_android_full",
            "component": "modules/settings/configs/PowerConfig.qml",
            "subPages": ["widgets/CorePowerConfig.qml"],
            "aliases": ["Battery warning"]
        }
    ]
}
'''

POWER_PAGE = '''
ContentSection {
    icon: "battery_android_full"
    title: Translation.tr("Power & Battery Management")

    ConfigSwitch {
        buttonIcon: "pause"
        text: Translation.tr("Automatic suspend")
        checked: Config.options.battery.automaticSuspend
        StyledToolTip { text: Translation.tr("Automatically suspends the system") }
    }

    ConfigSpinBox {
        enabled: Config.options.battery.automaticSuspend
        icon: "mode_standby"
        text: Translation.tr("Suspend at (%)")
        value: Config.options.battery.suspend
        from: 0
        to: 100
        stepSize: 5
    }
}
'''


class SettingsIndexTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        (self.root / "modules/common").mkdir(parents=True)
        (self.root / "modules/settings/configs/widgets").mkdir(parents=True)
        (self.root / "translations").mkdir()
        (self.root / "scripts/ai").mkdir(parents=True)
        (self.root / "modules/common/SettingsPageRegistry.qml").write_text(REGISTRY, encoding="utf-8")
        (self.root / "modules/settings/configs/PowerConfig.qml").write_text(POWER_PAGE, encoding="utf-8")
        # Deliberately duplicate the switch in a subpage: one key must create
        # one entry with the second location retained in alsoIn.
        (self.root / "modules/settings/configs/widgets/CorePowerConfig.qml").write_text(POWER_PAGE, encoding="utf-8")
        (self.root / "translations/pt_BR.json").write_text(json.dumps({
            "Automatic suspend": "Suspensão automática",
            "Automatically suspends the system": "Suspende o sistema automaticamente",
            "Power & Battery Management": "Gerenciamento de Energia e Bateria",
            "Power & Battery": "Energia e Bateria",
            "Suspend at (%)": "Suspender em (%)",
        }), encoding="utf-8")
        (self.root / "scripts/ai/settings_synonyms.json").write_text(json.dumps({
            "suspend": ["suspender", "dormir", "sleep"],
        }), encoding="utf-8")
        self.config = self.root / "config.json"
        self.config.write_text(json.dumps({"battery": {
            "automaticSuspend": True,
            "suspend": 25,
            "headlessValue": "007",
        }}), encoding="utf-8")
        self.out = self.root / "settings_index.json"

    def tearDown(self):
        self.tempdir.cleanup()

    def build(self, language="pt_BR"):
        return ai_settings_index.build_index(
            root=self.root,
            config_path=self.config,
            language=language,
            output_path=self.out,
        )

    def test_extracts_keys_types_ranges_dependencies_and_labels(self):
        index = self.build()
        entries = {entry["key"]: entry for entry in index["entries"]}

        automatic = entries["battery.automaticSuspend"]
        self.assertEqual(automatic["type"], "bool")
        self.assertEqual(automatic["widget"], "ConfigSwitch")
        # One label, in the requested language. The index used to carry both
        # and hand both onwards, which is how an English interface answered
        # with Portuguese toggle names.
        self.assertEqual(automatic["label"], "Suspensão automática")
        self.assertEqual(automatic["sectionTitle"], "Gerenciamento de Energia e Bateria")
        self.assertNotIn("labelLocalized", automatic)
        self.assertEqual(automatic["pageId"], "power")
        self.assertEqual(automatic["currentValue"], True)
        self.assertEqual(automatic["alsoIn"], [{"pageId": "power", "subPage": "widgets/CorePowerConfig.qml"}])

        suspend = entries["battery.suspend"]
        self.assertEqual(suspend["type"], "int")
        self.assertEqual(suspend["range"], {"from": 0, "to": 100, "step": 5})
        self.assertEqual(suspend["dependsOn"], "battery.automaticSuspend")

        # Config leaves without a visual control remain safe to read and type
        # validate, but are never offered as a fake in-UI result.
        self.assertFalse(entries["battery.headlessValue"]["hasUi"])
        self.assertEqual(entries["battery.headlessValue"]["type"], "string")

    def test_no_language_leaves_the_source_strings_alone(self):
        # What an English interface asks for: nothing to translate into, so
        # the labels written in the QML are what comes back.
        entries = {entry["key"]: entry for entry in self.build(language="")["entries"]}
        self.assertEqual(entries["battery.automaticSuspend"]["label"], "Automatic suspend")
        self.assertEqual(entries["battery.automaticSuspend"]["sectionTitle"], "Power & Battery Management")

    def test_search_finds_by_the_translated_label_and_by_synonym(self):
        index = self.build()
        localized = ai_settings_index.search_entries(index, "suspensão automática")
        self.assertEqual(localized[0]["key"], "battery.automaticSuspend")

        synonym = ai_settings_index.search_entries(index, "dormir")
        self.assertEqual(synonym[0]["key"], "battery.automaticSuspend")
        self.assertGreater(synonym[0]["score"], 0)

    def test_a_translated_index_is_still_searchable_in_english(self):
        # The untranslated strings stay in `match` for exactly this: someone
        # who knows the option by its English name, in a Portuguese interface.
        index = self.build()
        results = ai_settings_index.search_entries(index, "automatic suspend")
        self.assertEqual(results[0]["key"], "battery.automaticSuspend")

    def test_check_detects_source_changes(self):
        index = self.build()
        self.assertTrue(ai_settings_index.index_is_current(index, self.root, "pt_BR"))
        page = self.root / "modules/settings/configs/PowerConfig.qml"
        page.write_text(POWER_PAGE + "\n// source changed\n", encoding="utf-8")
        self.assertFalse(ai_settings_index.index_is_current(index, self.root, "pt_BR"))


if __name__ == "__main__":
    unittest.main()
