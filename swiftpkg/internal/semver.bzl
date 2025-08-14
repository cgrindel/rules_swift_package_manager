"""Module for parsing semver strings into components"""

def _major_minor(version):
    version_components = version.split(".") + ["0", "0"]
    version_major, version_minor = [int(x if x.isdigit() else "0") for x in version_components[0:2]]
    return (version_major, version_minor)

semver = struct(
    major_minor = _major_minor,
)
