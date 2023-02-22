"""Module for retrieving info about Objective-C files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load(":apple_builtin_frameworks.bzl", "apple_builtin_frameworks")

_pound_import = "#import "
_pound_import_len = len(_pound_import)
_at_import = "@import "
_at_import_len = len(_at_import)

def _parse_pound_import(line):
    import_idx = line.find(_pound_import)
    if import_idx < 0:
        return None
    start_idx = import_idx + _pound_import_len
    line_len = len(line)

    # DEBUG BEGIN
    print("*** CHUCK line: ", line)
    print("*** CHUCK start_idx: ", start_idx)
    print("*** CHUCK line_len: ", line_len)
    # DEBUG END

    # Find the opening bracket
    open_bracket_idx = -1
    for idx in range(start_idx, line_len - start_idx):
        char = line[idx]

        # DEBUG BEGIN
        print("*** CHUCK char: ", char)

        # DEBUG END
        if char == " " or char == "\t":
            continue
        elif char == "<":
            open_bracket_idx = idx
            break
        else:
            return None
    if open_bracket_idx < 0:
        return None
    framework_start_idx = open_bracket_idx + 1

    # DEBUG BEGIN
    print("*** CHUCK framework_start_idx: ", framework_start_idx)
    # DEBUG END

    # Find the first slash (/)
    slash_idx = -1
    for idx in range(open_bracket_idx, line_len - open_bracket_idx):
        char = line[idx]
        if char == "/":
            slash_idx = idx
    if slash_idx < 0:
        return None

    # DEBUG BEGIN
    print("*** CHUCK slash_idx: ", slash_idx)
    # DEBUG END

    return line[framework_start_idx:slash_idx]

def _parse_at_import(line):
    # TODO(chuck): IMPLEMENT ME!
    pass

def _parse_for_imported_framework(line):
    if line == None or line == "":
        return None

    def _verify(name):
        if sets.contains(apple_builtin_frameworks.all, name):
            return name
        else:
            return None

    framework = _parse_pound_import(line)

    # DEBUG BEGIN
    print("*** CHUCK framework: ", framework)

    # DEBUG END
    if framework != None:
        return _verify(framework)
    framework = _parse_at_import(line)
    if framework != None:
        return _verify(framework)
    return None

def _collect_frameworks_for_src(repository_ctx, src_path):
    frameworks = []
    contents = repository_ctx.read(src_path)
    lines = contents.splitlines()
    for line in lines:
        imported_framework = _parse_for_imported_framework(line)
        if imported_framework != None:
            frameworks.append(imported_framework)
    return frameworks

def _collect_builtin_frameworks(repository_ctx, root_path, srcs):
    frameworks = sets.make()
    for src in srcs:
        src_path = paths.join(root_path, srcs)
        src_frameworks = _collect_frameworks_for_src(src_path)
        for sf in src_frameworks:
            sets.insert(frameworks, sf)
    return sorted(sets.to_list(frameworks))

objc_files = struct(
    collect_builtin_frameworks = _collect_builtin_frameworks,
    # Public for testing purposes
    parse_for_imported_framework = _parse_for_imported_framework,
)
