#!/usr/bin/env bash
# Keeps screen_protector unregistered on iOS (reader uses IosReaderProtection.swift).
# Re-run after flutter pub get regenerates GeneratedPluginRegistrant.m
set -euo pipefail

REGISTRANT="ios/Runner/GeneratedPluginRegistrant.m"
if [[ ! -f "$REGISTRANT" ]]; then
  echo "Missing $REGISTRANT"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
path = Path("ios/Runner/GeneratedPluginRegistrant.m")
text = path.read_text(encoding="utf-8")

import_block = """#if __has_include(<screen_protector/ScreenProtectorPlugin.h>)
#import <screen_protector/ScreenProtectorPlugin.h>
#else
@import screen_protector;
#endif"""

wrapped = """// iOS: screen_protector disabled — reader uses IosReaderProtection.swift instead.
#if 0
""" + import_block + """
#endif"""

if wrapped not in text:
    text = text.replace(import_block, wrapped)

register_line = '[ScreenProtectorPlugin registerWithRegistrar:[registry registrarForPlugin:@"ScreenProtectorPlugin"]];'
commented = """  // iOS: ScreenProtectorPlugin disabled — reader uses IosReaderProtection.swift instead.
  // """ + register_line

if commented not in text and register_line in text:
    text = text.replace("  " + register_line, commented)

path.write_text(text, encoding="utf-8")
print("Patched iOS screen_protector bypass in GeneratedPluginRegistrant.m")
PY
