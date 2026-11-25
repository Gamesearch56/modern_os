"""Media types the ModernOS Mediaplayer opens: what Qt Multimedia's FFmpeg
backend plays. The desktop entry's MimeType= lists exactly these types
(tests/test-player.sh checks it), so Files never hands the player a file
it was not meant for.
"""

# extension -> (mime type, "video" or "audio")
FORMATS = {
    "mp4": ("video/mp4", "video"),
    "m4v": ("video/x-m4v", "video"),
    "mkv": ("video/x-matroska", "video"),
    "webm": ("video/webm", "video"),
    "avi": ("video/x-msvideo", "video"),
    "mov": ("video/quicktime", "video"),
    "wmv": ("video/x-ms-wmv", "video"),
    "flv": ("video/x-flv", "video"),
    "mpg": ("video/mpeg", "video"),
    "mpeg": ("video/mpeg", "video"),
    "ts": ("video/mp2t", "video"),
    "m2ts": ("video/mp2t", "video"),
    "mts": ("video/mp2t", "video"),
    "ogv": ("video/ogg", "video"),
    "3gp": ("video/3gpp", "video"),
    "mp3": ("audio/mpeg", "audio"),
    "flac": ("audio/flac", "audio"),
    "ogg": ("audio/ogg", "audio"),
    "oga": ("audio/ogg", "audio"),
    "opus": ("audio/opus", "audio"),
    "m4a": ("audio/mp4", "audio"),
    "aac": ("audio/aac", "audio"),
    "wav": ("audio/x-wav", "audio"),
    "wma": ("audio/x-ms-wma", "audio"),
    "mka": ("audio/x-matroska", "audio"),
}


def ext(path):
    name = path.rsplit("/", 1)[-1]
    if "." not in name:
        return ""
    return name.rsplit(".", 1)[-1].lower()


def supported(path):
    return ext(path) in FORMATS


def mime(path):
    row = FORMATS.get(ext(path))
    return row[0] if row else ""


def kind(path):
    row = FORMATS.get(ext(path))
    return row[1] if row else ""


def mime_types():
    return sorted({m for m, _k in FORMATS.values()})
