#!/usr/bin/env bash
# Re-applies the iOS screen_protector registration bypass after flutter pub get
# regenerates ios/Runner/GeneratedPluginRegistrant.m
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

wrapped = """// iOS isolation: screen_protector registration disabled for black-screen diagnosis.
// Android still uses the plugin via its own registrant path.
#if 0
""" + import_block + """
#endif"""

if wrapped not in text:
    text = text.replace(import_block, wrapped)

register_line = '[ScreenProtectorPlugin registerWithRegistrar:[registry registrarForPlugin:@"ScreenProtectorPlugin"]];'
commented = """  // iOS isolation: ScreenProtectorPlugin disabled — see ScreenProtectionHelper Dart bypass.
  // """ + register_line

if commented not in text and register_line in text:
    text = text.replace(
        "  " + register_line,
        commented,
    )

path.write_text(text, encoding="utf-8")
print("Patched screen_protector bypass in GeneratedPluginRegistrant.m")
PY
