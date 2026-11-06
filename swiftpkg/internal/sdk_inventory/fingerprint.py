"""Hash the provider's watched physical files, without following directory cycles."""

import hashlib
import json
import sys


def fingerprint(paths):
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.encode("utf-8") + b"\0")
        file_digest = hashlib.sha256()
        with open(path, "rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                file_digest.update(block)
        digest.update(file_digest.digest())
    return digest.hexdigest()


if __name__ == "__main__":
    with open(sys.argv[1]) as manifest:
        print(fingerprint(json.load(manifest)))
