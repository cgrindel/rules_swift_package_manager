"""Watch SDK/compiler identity or contents once in the shared provider."""

def _collect(ctx, developer_dir, swiftc, sdks, full):
    # These files identify an immutable Xcode installation without walking SDKs.
    # Watch the version file itself: xcodebuild's stdout is not a tracked input.
    roots = [swiftc, str(ctx.path(developer_dir).dirname) + "/version.plist"]
    roots.extend([p + "/SDKSettings.json" for p in sdks.values()])
    if full:
        roots.append(str(ctx.path(swiftc).dirname.dirname) + "/lib")
        roots.extend(sdks.values())
        for sdk_path in sdks.values():
            platform_developer = str(ctx.path(sdk_path).dirname.dirname)
            roots.extend([
                platform_developer + suffix
                for suffix in ["/Library/Frameworks", "/usr/lib"]
            ])
    return _manifest(ctx, roots)

def _manifest(ctx, roots):
    # SDKs contain directory aliases and cycles (e.g. Ruby.framework headers).
    # watch_tree follows those links without a visited set. Watch physical
    # directories and files once, including directory membership for new
    # modules.
    pending = roots
    visited = {}
    files = []
    layout = {}
    for _ in range(128):
        if not pending:
            return {
                "files": sorted(files),
                "layout": [[p] + layout[p] for p in sorted(layout)],
            }
        current = pending
        pending = []
        for logical in current:
            path = ctx.path(logical)
            if not path.exists:
                ctx.watch(logical)
                layout[logical] = [None, "missing"]
                continue
            canonical = str(path.realpath)

            # Track aliases even when their physical destination was visited.
            # Ordinary files are watched below only once; readdir watches
            # directory membership without an additional directory watch.
            if logical != canonical:
                ctx.watch(logical)
            is_dir = visited.get(canonical)
            if is_dir == None:
                is_dir = path.is_dir
            layout[logical] = [canonical, "directory" if is_dir else "file"]
            if canonical in visited:
                continue
            visited[canonical] = is_dir
            if is_dir:
                physical = ctx.path(canonical)
                children = physical.readdir(watch = "yes")
                pending.extend([str(p) for p in children])
            else:
                ctx.watch(canonical)
                files.append(canonical)
    fail("SDK input directory traversal exceeded 128 levels.")

sdk_inventory_inputs = struct(collect = _collect, manifest = _manifest)
