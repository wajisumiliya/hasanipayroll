#!/usr/bin/env python3
"""Restore the existing upload key for CI; never generate a replacement key."""

import base64
import os
from pathlib import Path


def escape_property(value):
    result = []
    for char in value:
        if char == "\\":
            result.append("\\\\")
        elif char == "\n":
            result.append("\\n")
        elif char == "\r":
            result.append("\\r")
        elif char == "\t":
            result.append("\\t")
        elif char in " =:#!":
            result.append("\\" + char)
        elif ord(char) > 127:
            data = char.encode("utf-16-be")
            result.extend(
                "\\u%04x" % int.from_bytes(data[i:i + 2], "big")
                for i in range(0, len(data), 2)
            )
        else:
            result.append(char)
    return "".join(result)


def main():
    names = (
        "ANDROID_KEYSTORE_BASE64", "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD", "ANDROID_STORE_PASSWORD",
    )
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing GitHub signing secrets: " + ", ".join(missing))
    try:
        key_bytes = base64.b64decode(os.environ[names[0]], validate=True)
    except ValueError:
        raise SystemExit("ANDROID_KEYSTORE_BASE64 must contain valid base64") from None
    if not key_bytes:
        raise SystemExit("Upload keystore must not be empty")
    key = Path("android/app/upload-keystore.jks")
    properties = Path("android/key.properties")
    if key.exists() or properties.exists():
        raise SystemExit("Refusing to overwrite existing local signing files")
    values = {
        "storeFile": "upload-keystore.jks",
        "keyAlias": os.environ["ANDROID_KEY_ALIAS"],
        "keyPassword": os.environ["ANDROID_KEY_PASSWORD"],
        "storePassword": os.environ["ANDROID_STORE_PASSWORD"],
    }
    # Set private permissions at creation, before writing any key or password.
    with key.open("xb") as stream:
        os.chmod(key, 0o600)
        stream.write(key_bytes)
    with properties.open("x", encoding="ascii") as stream:
        os.chmod(properties, 0o600)
        stream.write("".join(k + "=" + escape_property(v) + "\n" for k, v in values.items()))


if __name__ == "__main__":
    main()
