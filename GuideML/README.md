# GuideML (vendored)

AmigaGuide → HTML converter by Richard Körber and Chris Young.

Upstream: https://github.com/chris-y/guideml  
License: GNU GPL v2 or later (see `LICENSE`)

This copy is built for macOS using GuideML’s Haiku port (`-D__HAIKU__`) plus small host shims in `Headers/macos`. `guideml.c` is patched so conversion can be called more than once in-process (reset globals, avoid double-free).
