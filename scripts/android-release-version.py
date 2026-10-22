#!/usr/bin/env python3
"""Resolve release labels and Flutter version overrides from the same metadata."""

import json
import os
from pathlib import Path
import re


def main():
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$",
                      Path("pubspec.yaml").read_text(), re.MULTILINE)
    if not match:
        raise SystemExit("pubspec.yaml needs a version such as 1.0.7+14")
    name, saved_code = match.groups()
    requested = os.environ.get("REQUESTED_BUILD_NUMBER", "").strip()
    code = requested or saved_code
    if not re.fullmatch(r"[1-9][0-9]*", code):
        raise SystemExit("Version code must be a positive integer")
    if not int(saved_code) <= int(code) <= 2100000000:
        raise SystemExit("Version code must be at least the repository version and at most 2100000000")
    values = {
        "version_name": name,
        "version_code": code,
        "bundle_name": f"hasani-payroll-{name}-{code}.aab",
        "artifact_name": f"HASANI-PAYROLL-PLAYSTORE-SIGNED-{name}-{code}",
    }
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as stream:
            stream.write("".join(f"{key}={value}\n" for key, value in values.items()))
    print(json.dumps(values))


if __name__ == "__main__":
    main()
