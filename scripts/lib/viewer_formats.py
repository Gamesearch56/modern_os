"""Image types the ModernOS Imageviewer opens: what Qt decodes with qt6-svg
and qt6-imageformats. The desktop entry's MimeType= lists exactly these
types (tests/test-viewer.sh checks it), so Files never hands the viewer
a file it cannot show.
"""

# extension -> (mime type, ImageMagick format for a saved rotation or None)
FORMATS = {
    "png": ("image/png", "PNG"),
    "jpg": ("image/jpeg", "JPEG"),
    "jpeg": ("image/jpeg", "JPEG"),
    "jpe": ("image/jpeg", "JPEG"),
    "jfif": ("image/jpeg", "JPEG"),
    "gif": ("image/gif", "GIF"),
    "webp": ("image/webp", "WEBP"),
    "bmp": ("image/bmp", "BMP"),
    "tif": ("image/tiff", "TIFF"),
    "tiff": ("image/tiff", "TIFF"),
    "svg": ("image/svg+xml", None),
    "svgz": ("image/svg+xml-compressed", None),
    "ico": ("image/vnd.microsoft.icon", None),
    "tga": ("image/x-tga", "TGA"),
    "icns": ("image/x-icns", None),
    "wbmp": ("image/vnd.wap.wbmp", None),
    "xpm": ("image/x-xpixmap", None),
    "xbm": ("image/x-xbitmap", None),
    "pbm": ("image/x-portable-bitmap", "PBM"),
    "pgm": ("image/x-portable-graymap", "PGM"),
    "ppm": ("image/x-portable-pixmap", "PPM"),
    "pnm": ("image/x-portable-anymap", "PNM"),
}

ANIMATED = {"gif", "webp"}


def ext(path):
    name = path.rsplit("/", 1)[-1]
    if "." not in name:
        return ""
    return name.rsplit(".", 1)[-1].lower()


def supported(path):
    return ext(path) in FORMATS


def mime(path):
    entry = FORMATS.get(ext(path))
    return entry[0] if entry else ""


def magick_format(path):
    entry = FORMATS.get(ext(path))
    return entry[1] if entry else None


def mime_types():
    return sorted({m for m, _ in FORMATS.values()})
