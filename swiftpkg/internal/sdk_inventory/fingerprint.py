"""Hash the provider's watched physical files.

Directory cycles are not followed.
"""

import hashlib
import json
import sys


def fingerprint(manifest):
    digest = hashlib.sha256()
    # Include aliases and directory membership, even when their physical targets
    # were already visited. Retargeting a symlink changes compiler lookup order.
    layout = json.dumps(manifest["layout"], separators=(",", ":"))
    digest.update(layout.encode("utf-8"))
    for path in manifest["files"]:
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
