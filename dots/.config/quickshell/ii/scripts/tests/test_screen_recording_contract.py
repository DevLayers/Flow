"""Contracts for the wf-recorder and region-selector integration.

These tests intentionally inspect the command boundary rather than starting a
Wayland capture.  They keep the regression coverage safe for headless CI and
avoid touching the user's active Quickshell session.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
RECORD = (ROOT / "scripts/videos/record.sh").read_text()
SCREENSHOT_ACTION = (ROOT / "modules/common/utils/ScreenshotAction.qml").read_text()
REGION_SELECTION = (ROOT / "modules/ii/regionSelector/RegionSelection.qml").read_text()
WAFFLE_REGION_SELECTION = (ROOT / "modules/waffle/screenSnip/WRegionSelectionPanel.qml").read_text()


class ScreenRecordingContractTests(unittest.TestCase):
    def test_audio_prefers_the_default_sink_monitor(self):
        body = RECORD.split("getaudiooutput() {", 1)[1].split("\n}\ngetactivemonitor", 1)[0]
        self.assertIn("pactl get-default-sink", body)
        self.assertIn('default_monitor="${default_sink}.monitor"', body)
        self.assertIn("pactl list short sources", body)
        self.assertLess(body.index("default_monitor"), body.index("$2 ~ /\\.monitor$/"))

    def test_region_command_has_a_logical_global_geometry_channel(self):
        self.assertIn("recordGeometry = null", SCREENSHOT_ACTION)
        self.assertIn("recordGeometry ? recordGeometry.x : x", SCREENSHOT_ACTION)
        self.assertIn("recordGeometry ? recordGeometry.y : y", SCREENSHOT_ACTION)
        self.assertIn("recordGeometry ? recordGeometry.width : width", SCREENSHOT_ACTION)
        self.assertIn("recordGeometry ? recordGeometry.height : height", SCREENSHOT_ACTION)
        self.assertIn("x: rx + root.monitorOffsetX", REGION_SELECTION)
        self.assertIn("y: ry + root.monitorOffsetY", REGION_SELECTION)
        self.assertIn("x: dragArea.selectionX + root.monitorOffsetX", WAFFLE_REGION_SELECTION)
        self.assertIn("y: dragArea.selectionY + root.monitorOffsetY", WAFFLE_REGION_SELECTION)

    def test_region_recording_does_not_force_the_focused_output(self):
        region_body = RECORD.split("# If a manual region was provided", 1)[1]
        region_body = region_body.split("# Post recording action", 1)[0]
        self.assertNotIn('wf-recorder -o "$(getactivemonitor)"', region_body)

    def test_recording_does_not_open_the_screenshot_overlay(self):
        snip_body = REGION_SELECTION.split("function snip()", 1)[1]
        overlay_body = snip_body.split("// Trigger screenshot overlay", 1)[1]
        overlay_body = overlay_body.split("root.dismiss();", 1)[0]
        self.assertIn("const isRecording", REGION_SELECTION)
        self.assertIn("if (!isRecording &&", overlay_body)


if __name__ == "__main__":
    unittest.main()
