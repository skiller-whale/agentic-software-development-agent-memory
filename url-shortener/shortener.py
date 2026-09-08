"""Shortens URLs to six-character codes and expands them again."""

import hashlib

ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"

_links = {}


def code_for(url):
    digest = int(hashlib.sha256(url.encode()).hexdigest(), 16)
    code = ""
    while len(code) < 6:
        digest, i = divmod(digest, len(ALPHABET))
        code += ALPHABET[i]
    return code


def shorten(url):
    code = code_for(url)
    _links[code] = url
    return code


def expand(code):
    return _links.get(code)
