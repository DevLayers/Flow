#!/usr/bin/env python3
"""Launcher icon extractor for the Quickshell phone panel.

Android exposes no API to hand a launcher icon to a desktop, so icons are
resolved out of the installed APKs over adb:

  1. `pm path <pkg>` lists the base APK plus its config splits.
  2. `AndroidManifest.xml` and `resources.arsc` are streamed out of the APK
     with the device's own `unzip -p`, so a 200 MB app costs a few hundred KB
     rather than a full pull.
  3. The manifest's `application@icon` resource id is resolved against the
     resource table to a concrete file inside one of the APKs.
  4. Bitmaps are converted to PNG; adaptive icons are flattened by compositing
     their foreground over their background and cropping to the safe zone;
     vector drawables are translated to SVG, which Qt renders natively.

Results are cached under XDG_CACHE_HOME so the adb round trips happen once per
app. Speaks newline-delimited JSON on stdin/stdout:

  {"cmd": "cached", "deviceId": "..."}                    -> {"event": "cached", "icons": {...}}
  {"cmd": "fetch", "package": "...", "deviceId": "...",   -> {"event": "icon", "package": "...", "path": "..."}
   "target_args": ["-s", "..."]}
  {"cmd": "clear", "deviceId": "..."}                     -> {"event": "cleared"}
"""

import base64
import json
import logging
import os
import queue
import shlex
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
import zipfile
from io import BytesIO
from pathlib import Path

logging.getLogger("pyaxmlparser").setLevel(logging.CRITICAL)

try:
    from pyaxmlparser.axmlprinter import AXMLPrinter
    from pyaxmlparser.core import APK

    PARSER_AVAILABLE = True
except ImportError:
    PARSER_AVAILABLE = False

try:
    from PIL import Image

    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

ANDROID = "{http://schemas.android.com/apk/res/android}"
AAPT = "{http://schemas.android.com/aapt}"

CACHE_ROOT = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "quickshell" / "phone_app_icons"
MISS_TTL = 7 * 24 * 3600  # Retry apps we failed to resolve after a week
OUTPUT_SIZE = 192  # Icons are shown at ~36 px; 192 stays crisp on any scale factor
WORKER_COUNT = 3
ADB_TIMEOUT = 25

RASTER_EXTS = (".png", ".webp", ".jpg", ".jpeg")
DENSITY_ANY = 0xFFFE  # anydpi: an XML drawable rather than a bitmap
DENSITY_NONE = 0xFFFF  # nodpi

# Adaptive icons draw 108x108 layers of which only the centre 72x72 is
# guaranteed visible; everything outside is parallax/mask bleed.
ADAPTIVE_VIEWPORT = 108.0
ADAPTIVE_SAFE = 72.0
ADAPTIVE_INSET = (ADAPTIVE_VIEWPORT - ADAPTIVE_SAFE) / 2.0

out_lock = threading.Lock()


def emit(payload: dict) -> None:
    with out_lock:
        sys.stdout.write(json.dumps(payload) + "\n")
        sys.stdout.flush()


def warn(message: str) -> None:
    sys.stderr.write(f"[android_icon_extractor] {message}\n")
    sys.stderr.flush()


# ─── adb plumbing ────────────────────────────────────────────────────────────

target_lock = threading.Lock()
server_started = False
resolved_target = None


def ensure_server() -> None:
    """Start the adb server once, serialized. Several workers racing to spawn
    their own server is a reliable way to wedge adb for everyone else."""
    global server_started
    with target_lock:
        if server_started:
            return
        server_started = True
    try:
        subprocess.run(["adb", "start-server"], capture_output=True, timeout=ADB_TIMEOUT)
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"adb start-server failed: {exc}")


def resolve_target(target_args) -> list:
    """The live device list beats the serial the shell passed us: wireless
    debugging picks a new port on every toggle, so that serial goes stale."""
    global resolved_target
    ensure_server()
    with target_lock:
        if resolved_target is not None:
            return resolved_target

    usb, wireless = [], []
    try:
        res = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=ADB_TIMEOUT)
        for line in res.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                (wireless if ":" in parts[0] else usb).append(parts[0])
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"adb devices failed: {exc}")

    connected = usb or wireless
    target = ["-s", connected[0]] if connected else list(target_args or [])
    with target_lock:
        resolved_target = target
    return target


def forget_target() -> None:
    global resolved_target
    with target_lock:
        resolved_target = None


def device_online(target_args) -> bool:
    try:
        res = subprocess.run(["adb", *resolve_target(target_args), "get-state"],
                             capture_output=True, text=True, timeout=ADB_TIMEOUT)
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"adb get-state failed: {exc}")
        forget_target()
        return False

    if res.stdout.strip() != "device":
        forget_target()
        return False
    return True


def adb_text(target_args, *args) -> str:
    try:
        res = subprocess.run(["adb", *resolve_target(target_args), *args], capture_output=True,
                             timeout=ADB_TIMEOUT)
        return res.stdout.decode("utf-8", "replace")
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"adb {' '.join(args)} failed: {exc}")
        return ""


def adb_binary(target_args, command: str) -> bytes:
    try:
        res = subprocess.run(["adb", *resolve_target(target_args), "exec-out", command],
                             capture_output=True, timeout=ADB_TIMEOUT)
        return res.stdout
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"adb exec-out failed: {exc}")
        return b""


def apk_paths(target_args, package: str) -> list:
    lines = adb_text(target_args, "shell", "pm", "path", package).splitlines()
    return [line.strip()[len("package:"):] for line in lines if line.strip().startswith("package:")]


def read_entry(target_args, apk: str, entry: str) -> bytes:
    return adb_binary(target_args, f"unzip -p {shlex.quote(apk)} {shlex.quote(entry)}")


# ─── Resource tables ─────────────────────────────────────────────────────────

class ApkTable:
    """One APK's manifest and resource table, fetched without pulling the APK."""

    def __init__(self, target_args, path: str):
        self.target_args = target_args
        self.path = path
        self.apk = None
        self.resources = None

        manifest = read_entry(target_args, path, "AndroidManifest.xml")
        arsc = read_entry(target_args, path, "resources.arsc")
        if not manifest or not arsc:
            return

        stub = BytesIO()
        with zipfile.ZipFile(stub, "w") as archive:
            archive.writestr("AndroidManifest.xml", manifest)
            archive.writestr("resources.arsc", arsc)
        try:
            self.apk = APK(stub.getvalue(), raw=True)
            self.resources = self.apk.get_android_resources()
        except Exception as exc:
            warn(f"cannot parse {os.path.basename(path)}: {exc}")

    @property
    def valid(self) -> bool:
        return self.resources is not None

    def icon_id(self):
        if self.apk is None:
            return None
        for attribute in ("icon", "roundIcon"):
            try:
                value = self.apk.get_attribute_value("application", attribute)
            except Exception:
                continue
            parsed = parse_reference(value)
            if parsed is not None:
                return parsed
        return None

    def resolve(self, res_id: int) -> list:
        """Every (density, value) this table holds for a resource id."""
        if not self.valid:
            return []
        try:
            return [(config.get_density(), value) for config, value in self.resources.get_resolved_res_configs(res_id)]
        except Exception:
            return []

    def read(self, entry: str) -> bytes:
        return read_entry(self.target_args, self.path, entry)


class PackageResources:
    """The base APK's table, widened to the config splits only when needed."""

    def __init__(self, target_args, package: str):
        self.target_args = target_args
        self.paths = apk_paths(target_args, package)
        self.tables = []
        self._splits_loaded = False

        if self.paths:
            base = ApkTable(target_args, self.paths[0])
            if base.valid:
                self.tables.append(base)

    @property
    def valid(self) -> bool:
        return bool(self.tables)

    @property
    def base(self) -> ApkTable:
        return self.tables[0]

    def _load_splits(self) -> None:
        if self._splits_loaded:
            return
        self._splits_loaded = True
        for path in self.paths[1:]:
            table = ApkTable(self.target_args, path)
            if table.valid:
                self.tables.append(table)

    def candidates(self, res_id: int) -> list:
        """All (table, density, value) entries for a resource id."""
        found = [(table, density, value) for table in self.tables for density, value in table.resolve(res_id)]
        if found:
            return found
        # Density-split APKs carry their own slice of the resource table.
        self._load_splits()
        return [(table, density, value) for table in self.tables for density, value in table.resolve(res_id)]

    def best_bitmap(self, res_id: int):
        """Highest-density bitmap for a resource id, as (table, entry)."""
        rasters = [c for c in self.candidates(res_id) if c[2].lower().endswith(RASTER_EXTS)]
        if not rasters:
            return None
        table, _, entry = max(rasters, key=lambda c: density_rank(c[1]))
        return table, entry

    def drawable_xml(self, res_id: int):
        """Parsed XML drawable for a resource id, as (table, element)."""
        for table, _, value in self.candidates(res_id):
            if not value.lower().endswith(".xml"):
                continue
            element = parse_axml(table.read(value))
            if element is not None:
                return table, element
        return None

    def color(self, res_id: int):
        """A resource id resolved to a #AARRGGBB literal, following one hop
        through a colour state list if that is what it points at."""
        for _, _, value in self.candidates(res_id):
            if value.startswith("#"):
                return normalize_color(value)
        found = self.drawable_xml(res_id)
        if found is None:
            return None
        _, element = found
        for item in element.iter():
            literal = item.get(f"{ANDROID}color")
            if literal:
                return self.color_value(literal)
        return None

    def color_value(self, raw: str):
        """A colour attribute that may be a literal or a reference."""
        if not raw:
            return None
        if raw.startswith("#"):
            return normalize_color(raw)
        res_id = parse_reference(raw)
        return self.color(res_id) if res_id is not None else None


def density_rank(density: int) -> int:
    if density in (DENSITY_ANY, DENSITY_NONE):
        return 0
    return density or 160  # A default-config bitmap is mdpi by definition


def parse_reference(value):
    """`@7F0801F1` and `@0x7f0801f1` style resource references."""
    if not isinstance(value, str) or not value.startswith("@"):
        return None
    body = value[1:]
    if body.lower().startswith("0x"):
        body = body[2:]
    try:
        return int(body, 16)
    except ValueError:
        return None


def parse_axml(raw: bytes):
    if not raw:
        return None
    try:
        return ET.fromstring(AXMLPrinter(raw).get_xml())
    except Exception:
        return None


def normalize_color(literal: str):
    """Android #AARRGGBB / #RGB literals to an (svg colour, opacity) pair."""
    body = literal.lstrip("#")
    if len(body) == 3:
        body = "".join(c * 2 for c in body)
    elif len(body) == 4:
        body = "".join(c * 2 for c in body)
    if len(body) == 8:
        alpha = int(body[0:2], 16) / 255.0
        return f"#{body[2:]}", alpha
    if len(body) == 6:
        return f"#{body}", 1.0
    return None


# ─── Vector drawable to SVG ──────────────────────────────────────────────────

class VectorConverter:
    """Translates a compiled <vector> drawable into SVG.

    Path data survives aapt compilation verbatim and uses the same grammar as
    SVG's `d`, so the conversion is mostly a matter of renaming attributes and
    resolving colour references through the resource table.
    """

    def __init__(self, resources: PackageResources):
        self.resources = resources
        self.defs = []
        self.gradient_seq = 0

    def convert(self, vector, view_box: str, background=None) -> str:
        width = float(vector.get(f"{ANDROID}viewportWidth") or ADAPTIVE_VIEWPORT)
        height = float(vector.get(f"{ANDROID}viewportHeight") or ADAPTIVE_VIEWPORT)
        scale = ""
        if view_box == self.adaptive_view_box() and (width, height) != (ADAPTIVE_VIEWPORT, ADAPTIVE_VIEWPORT):
            # Some foregrounds declare a smaller viewport than the 108 grid.
            scale = f' transform="scale({ADAPTIVE_VIEWPORT / width:.6f},{ADAPTIVE_VIEWPORT / height:.6f})"'

        body = "".join(self.emit_node(child) for child in vector)
        alpha = vector.get(f"{ANDROID}alpha")
        opacity = f' opacity="{float(alpha):.3f}"' if alpha else ""

        parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}" '
            f'width="{OUTPUT_SIZE}" height="{OUTPUT_SIZE}">'
        ]
        if self.defs:
            parts.append("<defs>" + "".join(self.defs) + "</defs>")
        if background:
            parts.append(background)
        parts.append(f"<g{scale}{opacity}>{body}</g></svg>")
        return "".join(parts)

    @staticmethod
    def adaptive_view_box() -> str:
        return f"{ADAPTIVE_INSET:g} {ADAPTIVE_INSET:g} {ADAPTIVE_SAFE:g} {ADAPTIVE_SAFE:g}"

    def emit_node(self, node) -> str:
        tag = node.tag.rsplit("}", 1)[-1]
        if tag == "path":
            return self.emit_path(node)
        if tag == "group":
            return self.emit_group(node)
        if tag == "clip-path":
            return ""  # Clips only ever shrink the drawing; ignoring them is safe
        return ""

    def emit_group(self, group) -> str:
        transforms = []
        translate_x = float(group.get(f"{ANDROID}translateX") or 0)
        translate_y = float(group.get(f"{ANDROID}translateY") or 0)
        pivot_x = float(group.get(f"{ANDROID}pivotX") or 0)
        pivot_y = float(group.get(f"{ANDROID}pivotY") or 0)
        rotation = float(group.get(f"{ANDROID}rotation") or 0)
        scale_x = float(group.get(f"{ANDROID}scaleX") or 1)
        scale_y = float(group.get(f"{ANDROID}scaleY") or 1)

        if translate_x or translate_y:
            transforms.append(f"translate({translate_x:g},{translate_y:g})")
        if rotation:
            transforms.append(f"rotate({rotation:g},{pivot_x:g},{pivot_y:g})")
        if scale_x != 1 or scale_y != 1:
            if pivot_x or pivot_y:
                transforms.append(f"translate({pivot_x:g},{pivot_y:g})")
            transforms.append(f"scale({scale_x:g},{scale_y:g})")
            if pivot_x or pivot_y:
                transforms.append(f"translate({-pivot_x:g},{-pivot_y:g})")

        body = "".join(self.emit_node(child) for child in group)
        attribute = f' transform="{" ".join(transforms)}"' if transforms else ""
        return f"<g{attribute}>{body}</g>"

    def emit_path(self, path) -> str:
        data = path.get(f"{ANDROID}pathData")
        if not data:
            return ""

        attributes = [f'd="{escape(data)}"']
        fill = self.paint(path, "fillColor")
        if fill is None:
            attributes.append('fill="none"')
        else:
            paint, opacity = fill
            attributes.append(f'fill="{paint}"')
            alpha = path.get(f"{ANDROID}fillAlpha")
            opacity *= float(alpha) if alpha else 1.0
            if opacity < 1.0:
                attributes.append(f'fill-opacity="{opacity:.3f}"')

        if (path.get(f"{ANDROID}fillType") or "0") in ("1", "evenOdd"):
            attributes.append('fill-rule="evenodd"')

        stroke = self.paint(path, "strokeColor")
        stroke_width = float(path.get(f"{ANDROID}strokeWidth") or 0)
        if stroke is not None and stroke_width > 0:
            paint, opacity = stroke
            attributes.append(f'stroke="{paint}" stroke-width="{stroke_width:g}"')
            alpha = path.get(f"{ANDROID}strokeAlpha")
            opacity *= float(alpha) if alpha else 1.0
            if opacity < 1.0:
                attributes.append(f'stroke-opacity="{opacity:.3f}"')
            cap = path.get(f"{ANDROID}strokeLineCap")
            join = path.get(f"{ANDROID}strokeLineJoin")
            if cap in ("round", "square"):
                attributes.append(f'stroke-linecap="{cap}"')
            if join in ("round", "bevel"):
                attributes.append(f'stroke-linejoin="{join}"')

        return f"<path {' '.join(attributes)}/>"

    def paint(self, path, attribute: str):
        """A fill/stroke as (svg paint, opacity), following gradients."""
        gradient = self.find_gradient(path, attribute)
        if gradient is not None:
            reference = self.emit_gradient(gradient)
            if reference:
                return reference, 1.0

        colour = self.resources.color_value(path.get(f"{ANDROID}{attribute}"))
        return colour

    @staticmethod
    def find_gradient(path, attribute: str):
        """aapt inlines `<aapt:attr name="android:fillColor"><gradient/></aapt:attr>`."""
        for child in path:
            if child.tag != f"{AAPT}attr" or child.get("name") != f"android:{attribute}":
                continue
            for grandchild in child:
                if grandchild.tag.rsplit("}", 1)[-1] == "gradient":
                    return grandchild
        return None

    def emit_gradient(self, gradient):
        stops = []
        for item in gradient:
            if item.tag.rsplit("}", 1)[-1] != "item":
                continue
            colour = self.resources.color_value(item.get(f"{ANDROID}color"))
            if colour is None:
                continue
            paint, opacity = colour
            offset = float(item.get(f"{ANDROID}offset") or 0)
            stops.append(f'<stop offset="{offset:g}" stop-color="{paint}" stop-opacity="{opacity:.3f}"/>')

        if not stops:
            for endpoint in ("startColor", "endColor"):
                colour = self.resources.color_value(gradient.get(f"{ANDROID}{endpoint}"))
                if colour is None:
                    continue
                paint, opacity = colour
                offset = 0 if endpoint == "startColor" else 1
                stops.append(f'<stop offset="{offset}" stop-color="{paint}" stop-opacity="{opacity:.3f}"/>')
        if not stops:
            return None

        self.gradient_seq += 1
        name = f"g{self.gradient_seq}"
        kind = gradient.get(f"{ANDROID}type") or "linear"
        if kind in ("1", "radial"):
            centre_x = gradient.get(f"{ANDROID}centerX") or 0
            centre_y = gradient.get(f"{ANDROID}centerY") or 0
            radius = gradient.get(f"{ANDROID}gradientRadius") or 1
            self.defs.append(
                f'<radialGradient id="{name}" gradientUnits="userSpaceOnUse" '
                f'cx="{centre_x}" cy="{centre_y}" r="{radius}">{"".join(stops)}</radialGradient>'
            )
        elif kind in ("2", "sweep"):
            # SVG has no sweep gradient; fall back to the plain colour attribute.
            self.gradient_seq -= 1
            return None
        else:
            self.defs.append(
                f'<linearGradient id="{name}" gradientUnits="userSpaceOnUse" '
                f'x1="{gradient.get(f"{ANDROID}startX") or 0}" y1="{gradient.get(f"{ANDROID}startY") or 0}" '
                f'x2="{gradient.get(f"{ANDROID}endX") or 0}" y2="{gradient.get(f"{ANDROID}endY") or 0}">'
                f'{"".join(stops)}</linearGradient>'
            )
        return f"url(#{name})"


def with_extension(stem: Path, extension: str) -> Path:
    # Not Path.with_suffix: package names are dotted, and it would eat the TLD.
    return stem.with_name(stem.name + extension)


def escape(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace('"', "&quot;")


# ─── Bitmap output ───────────────────────────────────────────────────────────

def write_bitmap(data: bytes, destination: Path, crop_to_safe_zone: bool, background=None) -> bool:
    if not PIL_AVAILABLE or not data:
        return False
    try:
        image = Image.open(BytesIO(data)).convert("RGBA")
        if background is not None:
            if isinstance(background, bytes):
                backdrop = Image.open(BytesIO(background)).convert("RGBA").resize(image.size, Image.LANCZOS)
            else:
                paint, alpha = background
                rgb = tuple(int(paint[i:i + 2], 16) for i in (1, 3, 5))
                backdrop = Image.new("RGBA", image.size, rgb + (int(alpha * 255),))
            backdrop.alpha_composite(image)
            image = backdrop
        if crop_to_safe_zone:
            inset_x = image.width * ADAPTIVE_INSET / ADAPTIVE_VIEWPORT
            inset_y = image.height * ADAPTIVE_INSET / ADAPTIVE_VIEWPORT
            image = image.crop((round(inset_x), round(inset_y),
                                round(image.width - inset_x), round(image.height - inset_y)))
        if max(image.size) > OUTPUT_SIZE:
            image.thumbnail((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)
        image.save(destination, "PNG")
        return True
    except Exception as exc:
        warn(f"cannot write {destination.name}: {exc}")
        return False


def background_markup(resources: PackageResources, reference) -> str:
    """The adaptive background layer as SVG markup behind the foreground."""
    res_id = parse_reference(reference)
    if res_id is None:
        colour = resources.color_value(reference)
        if colour is None:
            return ""
        paint, alpha = colour
        return f'<rect x="0" y="0" width="{ADAPTIVE_VIEWPORT:g}" height="{ADAPTIVE_VIEWPORT:g}" fill="{paint}" opacity="{alpha:.3f}"/>'

    colour = resources.color(res_id)
    if colour is not None:
        paint, alpha = colour
        return f'<rect x="0" y="0" width="{ADAPTIVE_VIEWPORT:g}" height="{ADAPTIVE_VIEWPORT:g}" fill="{paint}" opacity="{alpha:.3f}"/>'

    bitmap = find_bitmap(resources, res_id)
    if bitmap is not None:
        table, entry = bitmap
        data = table.read(entry)
        if data:
            mime = "png" if entry.lower().endswith(".png") else "webp" if entry.lower().endswith(".webp") else "jpeg"
            encoded = base64.b64encode(data).decode("ascii")
            return (f'<image x="0" y="0" width="{ADAPTIVE_VIEWPORT:g}" height="{ADAPTIVE_VIEWPORT:g}" '
                    f'href="data:image/{mime};base64,{encoded}"/>')

    vector = find_vector(resources, res_id)
    if vector is not None:
        nested = VectorConverter(resources)
        inner = "".join(nested.emit_node(child) for child in vector)
        defs = "<defs>" + "".join(nested.defs) + "</defs>" if nested.defs else ""
        return defs + f"<g>{inner}</g>"
    return ""


# ─── Icon resolution ─────────────────────────────────────────────────────────

def wrapped_references(element):
    """Drawable references reachable from a wrapper element.

    `<animated-vector>`, `<bitmap>`, `<layer-list>`, `<inset>` and the rest all
    delegate to another drawable through the same two attributes.
    """
    for node in element.iter():
        for attribute in (f"{ANDROID}drawable", f"{ANDROID}src"):
            res_id = parse_reference(node.get(attribute))
            if res_id is not None:
                yield res_id


def find_bitmap(resources: PackageResources, res_id: int, depth: int = 0):
    """The best bitmap for a resource id, unwrapping XML wrappers on the way."""
    bitmap = resources.best_bitmap(res_id)
    if bitmap is not None:
        return bitmap
    if depth > 3:
        return None
    drawable = resources.drawable_xml(res_id)
    if drawable is None or drawable[1].tag.rsplit("}", 1)[-1] == "adaptive-icon":
        return None
    for nested_id in wrapped_references(drawable[1]):
        found = find_bitmap(resources, nested_id, depth + 1)
        if found is not None:
            return found
    return None


def find_vector(resources: PackageResources, res_id: int, depth: int = 0):
    """The `<vector>` behind a resource id, unwrapping XML wrappers on the way."""
    drawable = resources.drawable_xml(res_id)
    if drawable is None:
        return None
    element = drawable[1]
    if element.tag.rsplit("}", 1)[-1] == "vector":
        return element
    if depth > 3 or element.tag.rsplit("}", 1)[-1] == "adaptive-icon":
        return None
    for nested_id in wrapped_references(element):
        found = find_vector(resources, nested_id, depth + 1)
        if found is not None:
            return found
    return None


def extract_icon(target_args, package: str, destination_stem: Path):
    """Resolve one package's launcher icon. Returns the written path, or None."""
    resources = PackageResources(target_args, package)
    if not resources.valid:
        return None

    icon_id = resources.base.icon_id()
    if icon_id is None:
        return None

    bitmap = resources.best_bitmap(icon_id)
    if bitmap is not None:
        table, entry = bitmap
        destination = with_extension(destination_stem, ".png")
        if write_bitmap(table.read(entry), destination, crop_to_safe_zone=False):
            return destination

    drawable = resources.drawable_xml(icon_id)
    if drawable is None:
        return None
    return render_drawable(resources, drawable[1], destination_stem, depth=0)


def render_drawable(resources: PackageResources, element, destination_stem: Path, depth: int):
    if depth > 3:
        return None
    tag = element.tag.rsplit("}", 1)[-1]

    if tag == "adaptive-icon":
        return render_adaptive(resources, element, destination_stem)

    if tag == "vector":
        destination = with_extension(destination_stem, ".svg")
        width = element.get(f"{ANDROID}viewportWidth") or ADAPTIVE_VIEWPORT
        height = element.get(f"{ANDROID}viewportHeight") or ADAPTIVE_VIEWPORT
        svg = VectorConverter(resources).convert(element, f"0 0 {float(width):g} {float(height):g}")
        destination.write_text(svg, encoding="utf-8")
        return destination

    for nested_id in wrapped_references(element):
        nested = resources.drawable_xml(nested_id)
        if nested is None:
            continue
        result = render_drawable(resources, nested[1], destination_stem, depth + 1)
        if result is not None:
            return result

    for nested_id in wrapped_references(element):
        bitmap = find_bitmap(resources, nested_id)
        if bitmap is None:
            continue
        destination = with_extension(destination_stem, ".png")
        if write_bitmap(bitmap[0].read(bitmap[1]), destination, crop_to_safe_zone=False):
            return destination
    return None


def render_adaptive(resources: PackageResources, element, destination_stem: Path):
    foreground = background = None
    for child in element:
        tag = child.tag.rsplit("}", 1)[-1]
        if tag == "foreground":
            foreground = child.get(f"{ANDROID}drawable")
        elif tag == "background":
            background = child.get(f"{ANDROID}drawable")
    if foreground is None:
        return None

    foreground_id = parse_reference(foreground)
    if foreground_id is None:
        return None

    bitmap = find_bitmap(resources, foreground_id)
    if bitmap is not None:
        table, entry = bitmap
        backdrop = None
        if background is not None:
            background_id = parse_reference(background)
            colour = resources.color(background_id) if background_id is not None else resources.color_value(background)
            if colour is not None:
                backdrop = colour
            elif background_id is not None:
                layer = find_bitmap(resources, background_id)
                if layer is not None:
                    backdrop = layer[0].read(layer[1])
        destination = with_extension(destination_stem, ".png")
        if write_bitmap(table.read(entry), destination, crop_to_safe_zone=True, background=backdrop):
            return destination

    vector = find_vector(resources, foreground_id)
    if vector is None:
        return None

    converter = VectorConverter(resources)
    backdrop = background_markup(resources, background) if background is not None else ""
    svg = converter.convert(vector, VectorConverter.adaptive_view_box(), background=backdrop)
    destination = with_extension(destination_stem, ".svg")
    destination.write_text(svg, encoding="utf-8")
    return destination


# ─── Cache ───────────────────────────────────────────────────────────────────

def cache_dir(device_id: str) -> Path:
    safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in (device_id or "default"))
    directory = CACHE_ROOT / safe
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def miss_file(device_id: str) -> Path:
    return cache_dir(device_id) / "_misses.json"


def load_misses(device_id: str) -> dict:
    try:
        return json.loads(miss_file(device_id).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def record_miss(device_id: str, package: str) -> None:
    misses = load_misses(device_id)
    misses[package] = int(time.time())
    try:
        miss_file(device_id).write_text(json.dumps(misses), encoding="utf-8")
    except OSError as exc:
        warn(f"cannot record miss: {exc}")


def cached_icon(device_id: str, package: str):
    for suffix in (".png", ".svg"):
        candidate = cache_dir(device_id) / f"{package}{suffix}"
        if candidate.exists():
            return candidate
    return None


def scan_cache(device_id: str) -> dict:
    icons = {}
    for entry in cache_dir(device_id).iterdir():
        if entry.suffix in (".png", ".svg"):
            icons[entry.name[:-len(entry.suffix)]] = str(entry)
    return icons


# ─── Worker loop ─────────────────────────────────────────────────────────────

work_queue = queue.Queue()
in_flight = set()
in_flight_lock = threading.Lock()


def handle_fetch(package: str, device_id: str, target_args: list) -> None:
    cached = cached_icon(device_id, package)
    if cached is not None:
        emit({"event": "icon", "package": package, "path": str(cached)})
        return

    misses = load_misses(device_id)
    if time.time() - misses.get(package, 0) < MISS_TTL:
        emit({"event": "icon", "package": package, "path": ""})
        return

    if not device_online(target_args):
        emit({"event": "icon", "package": package, "path": "", "retry": True})
        return

    result = None
    try:
        result = extract_icon(target_args, package, cache_dir(device_id) / package)
    except Exception as exc:
        warn(f"{package}: {exc}")

    if result is None:
        # A phone that went away mid-fetch says nothing about the app's icon.
        # Recording that as a miss would blacklist it for a week over what is
        # really a dropped connection.
        if not device_online(target_args):
            emit({"event": "icon", "package": package, "path": "", "retry": True})
            return
        record_miss(device_id, package)
        emit({"event": "icon", "package": package, "path": ""})
        return
    emit({"event": "icon", "package": package, "path": str(result)})


def worker() -> None:
    while True:
        job = work_queue.get()
        if job is None:
            return
        package, device_id, target_args = job
        try:
            handle_fetch(package, device_id, target_args)
        finally:
            with in_flight_lock:
                in_flight.discard((device_id, package))
            work_queue.task_done()


def handle_command(message: dict) -> None:
    command = message.get("cmd")
    device_id = message.get("deviceId") or "default"

    if command == "cached":
        emit({"event": "cached", "deviceId": device_id, "icons": scan_cache(device_id)})
        return

    if command == "clear":
        forget_target()
        for entry in cache_dir(device_id).iterdir():
            try:
                entry.unlink()
            except OSError:
                pass
        emit({"event": "cleared", "deviceId": device_id})
        return

    if command != "fetch":
        return

    package = message.get("package")
    if not package:
        return
    if not PARSER_AVAILABLE:
        emit({"event": "icon", "package": package, "path": ""})
        return

    key = (device_id, package)
    with in_flight_lock:
        if key in in_flight:
            return
        in_flight.add(key)
    work_queue.put((package, device_id, message.get("target_args") or []))


def main() -> None:
    if not PARSER_AVAILABLE:
        emit({"event": "unavailable", "reason": "python-pyaxmlparser is not installed"})
    elif not PIL_AVAILABLE:
        emit({"event": "unavailable", "reason": "python-pillow is not installed"})

    workers = [threading.Thread(target=worker, daemon=True) for _ in range(WORKER_COUNT)]
    for thread in workers:
        thread.start()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            handle_command(json.loads(line))
        except ValueError as exc:
            warn(f"bad command: {exc}")

    work_queue.join()  # Let queued extractions finish when stdin closes


if __name__ == "__main__":
    main()
