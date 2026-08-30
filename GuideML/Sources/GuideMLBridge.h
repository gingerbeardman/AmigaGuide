#pragma once

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Convert an AmigaGuide document into a single HTML file in `outputDirectory`.
/// GuideML names the file after the source (for example `Foo.guide.html`).
/// Returns true if GuideML ran; the caller should still check that HTML was written.
bool GuideMLConvertToDirectory(const char *inputPath,
                               const char *outputDirectory,
                               char *errorBuffer,
                               size_t errorBufferLength);

#ifdef __cplusplus
}
#endif
