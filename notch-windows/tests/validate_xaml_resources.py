"""Static check that app XAML resource references resolve from merged dictionaries."""

from collections import Counter
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/NotchWindows.App"
XAML_NS = "{http://schemas.microsoft.com/winfx/2006/xaml}"
RESOURCE_REFERENCE = re.compile(r"\{(?:StaticResource|ThemeResource)\s+([^}\s,]+)")


def main() -> int:
    app_tree = ET.parse(APP / "App.xaml")
    merged = app_tree.find(".//{*}ResourceDictionary.MergedDictionaries")
    if merged is None:
        raise SystemExit("App.xaml has no merged resource dictionaries")

    dictionary_paths = []
    for dictionary in merged:
        source = dictionary.get("Source")
        if dictionary.tag.endswith("XamlControlsResources"):
            continue
        if not source or source.startswith("ms-appx:"):
            raise SystemExit(f"Resource dictionary must use a local relative path: {source!r}")
        path = APP / source
        if not path.is_file():
            raise SystemExit(f"Merged resource dictionary does not exist: {path}")
        dictionary_paths.append(path)

    keys: Counter[str] = Counter()
    for path in dictionary_paths:
        tree = ET.parse(path)
        for element in tree.iter():
            key = element.get(XAML_NS + "Key")
            if key:
                keys[key] += 1
    duplicates = sorted(key for key, count in keys.items() if count > 1)
    if duplicates:
        raise SystemExit("Duplicate merged resource keys: " + ", ".join(duplicates))

    errors = []
    for path in APP.rglob("*.xaml"):
        tree = ET.parse(path)
        local_keys = {
            element.get(XAML_NS + "Key")
            for element in tree.iter()
            if element.get(XAML_NS + "Key")
        }
        available = set(keys) | local_keys
        source = path.read_text(encoding="utf-8-sig")
        for key in RESOURCE_REFERENCE.findall(source):
            if key not in available:
                errors.append(f"{path.relative_to(ROOT)}: unresolved resource {key}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print(f"Validated {len(dictionary_paths)} merged dictionaries and app XAML resource references.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
