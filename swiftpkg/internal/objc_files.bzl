"""Module for retrieving info about Objective-C files."""

_pound_import = "#import"
_pound_import_len = len(_pound_import)
_at_import = "@import"
_at_import_len = len(_at_import)

def _parse_pound_import(line, import_idx):
    # TODO(chuck): IMPLEMENT ME!
    pass

def _parse_at_import(line, import_idx):
    # TODO(chuck): IMPLEMENT ME!
    pass

def _imported_framework(line):
    def _verify(name):
        if name == None or name == "":
            return None
        if sets.contains(apple_builtin_frameworks.all, name):
            return name
        else:
            return None

    import_idx = line.find(_pound_import)
    if import_idx >= 0:
        # The directory name is the framework name.
        import_path = _parse_pound_import(line, import_idx)
        import_dir = paths.dirname(import_path)
        return _verify(import_dir)

    import_idx = line.find(_at_import)
    if import_idx >= 0:
        import_name = _parse_at_import(line, import_idx)
        return _verify(import_dir)

    return None

def _collect_frameworks_for_src(repository_ctx, src_path):
    frameworks = []
    contents = repository_ctx.read(src_path)
    lines = contents.splitlines()
    for line in lines:
        imported_framework = _imported_framework(line)
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
)
