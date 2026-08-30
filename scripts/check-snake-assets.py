#!/usr/bin/env python3

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SVG_NS = "http://www.w3.org/2000/svg"
APPROVED_NAMES = {"github-snake.svg", "github-snake-dark.svg"}
ALLOWED_ELEMENTS = {"svg", "style", "desc", "rect"}
ALLOWED_ATTRIBUTES = {
    "viewBox",
    "width",
    "height",
    "class",
    "x",
    "y",
    "rx",
    "ry",
}
ALLOWED_CSS_AT_RULES = {"keyframes"}
ALLOWED_CSS_FUNCTIONS = {"var", "scale", "translate"}


def fail(message: str) -> None:
    print(f"snake-assets: {message}", file=sys.stderr)
    raise SystemExit(1)


def split_name(name: str) -> tuple[str, str]:
    if name.startswith("{"):
        namespace, local_name = name[1:].split("}", 1)
        return namespace, local_name
    return "", name


def validate_style(css: str, asset_name: str) -> None:
    if "\\" in css or "/*" in css or "*/" in css:
        fail(f"external SVG reference rejected: {asset_name}")

    at_rules = {value.casefold() for value in re.findall(r"@([A-Za-z_-]+)", css)}
    functions = {
        value.casefold()
        for value in re.findall(r"([A-Za-z_-]+)\s*\(", css)
    }
    if not at_rules <= ALLOWED_CSS_AT_RULES:
        fail(f"external SVG reference rejected: {asset_name}")
    if not functions <= ALLOWED_CSS_FUNCTIONS:
        fail(f"external SVG reference rejected: {asset_name}")


def validate_svg(path: Path) -> None:
    size = path.stat().st_size
    if not 100 <= size <= 2_000_000:
        fail(f"SVG size outside allowed range: {path.name}")

    raw = path.read_bytes()
    if raw.startswith((b"\xef\xbb\xbf", b"\xff\xfe", b"\xfe\xff")):
        fail(f"SVG must be UTF-8 without BOM: {path.name}")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        fail(f"SVG must be UTF-8 without BOM: {path.name}")

    lowered = text.casefold()
    if "<!doctype" in lowered or "<!entity" in lowered or "<?" in text:
        fail(f"active SVG content rejected: {path.name}")

    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        fail(f"invalid XML: {path.name}")

    root_namespace, root_name = split_name(root.tag)
    if root_namespace != SVG_NS or root_name != "svg":
        fail(f"invalid SVG root: {path.name}")

    for element in root.iter():
        namespace, local_name = split_name(element.tag)

        for attribute_name in element.attrib:
            attribute_namespace, attribute_local_name = split_name(attribute_name)
            lowered_attribute = attribute_local_name.casefold()
            if lowered_attribute in {"href", "src"}:
                fail(f"external SVG reference rejected: {path.name}")
            if lowered_attribute.startswith("on"):
                fail(f"active SVG content rejected: {path.name}")
            if attribute_namespace or attribute_local_name not in ALLOWED_ATTRIBUTES:
                fail(f"active SVG content rejected: {path.name}")

        if namespace != SVG_NS or local_name not in ALLOWED_ELEMENTS:
            fail(f"active SVG content rejected: {path.name}")

        if local_name not in {"style", "desc"} and (element.text or "").strip():
            fail(f"active SVG content rejected: {path.name}")
        if (element.tail or "").strip():
            fail(f"active SVG content rejected: {path.name}")

        if local_name == "style":
            validate_style("".join(element.itertext()), path.name)


def main() -> None:
    asset_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "dist")
    if not asset_dir.is_dir():
        fail(f"asset directory not found: {asset_dir}")

    entries = list(asset_dir.iterdir())
    if len(entries) != 2:
        fail("expected exactly 2 asset entries")

    if {entry.name for entry in entries} != APPROVED_NAMES:
        unexpected = sorted(
            entry.name for entry in entries if entry.name not in APPROVED_NAMES
        )
        fail(f"unexpected asset entry: {unexpected[0]}")

    for entry in entries:
        if entry.is_symlink() or not entry.is_file():
            fail(f"asset must be a regular non-symlink file: {entry.name}")

    for name in sorted(APPROVED_NAMES):
        validate_svg(asset_dir / name)

    print("snake-assets: ok (2 passive SVGs)")


if __name__ == "__main__":
    main()
