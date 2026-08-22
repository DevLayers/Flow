#!/usr/bin/env python3
"""Regression contracts for bounded local Markdown image previews."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
AI_TEXT_BLOCK_QML = (ROOT / "services" / "ai" / "blocks" / "AiMessageTextBlock.qml").read_text(encoding="utf-8")
AI_IMAGE_PREVIEW_QML = (ROOT / "services" / "ai" / "blocks" / "AiImagePreview.qml").read_text(encoding="utf-8") if (ROOT / "services" / "ai" / "blocks" / "AiImagePreview.qml").exists() else ""


class MarkdownImagePreviewTests(unittest.TestCase):
    def test_local_markdown_images_use_a_bounded_image_component(self):
        self.assertIn('type: "image"', AI_TEXT_BLOCK_QML)
        self.assertIn("AiImagePreview", AI_TEXT_BLOCK_QML)
        self.assertIn("Image.PreserveAspectFit", AI_IMAGE_PREVIEW_QML)
        self.assertIn("sourceSize.width", AI_IMAGE_PREVIEW_QML)
        self.assertIn("sourceSize.height", AI_IMAGE_PREVIEW_QML)

    def test_image_preview_does_not_use_the_source_dimensions_as_layout_height(self):
        self.assertIn("previewAspectRatio", AI_IMAGE_PREVIEW_QML)
        self.assertIn("previewMaxHeight", AI_IMAGE_PREVIEW_QML)
        self.assertNotIn("height: implicitHeight", AI_IMAGE_PREVIEW_QML)


if __name__ == "__main__":
    unittest.main()
