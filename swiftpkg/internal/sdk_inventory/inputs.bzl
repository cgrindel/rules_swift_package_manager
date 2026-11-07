"""Watch SDK/compiler inputs once in the shared provider, tolerating directory aliases."""

def _manifest(ctx, roots):
    # SDKs contain directory aliases and cycles (e.g. Ruby.framework headers).
    # watch_tree follows those links without a visited set. Watch physical
    # directories and files once, including directory membership for new modules.
    pending = roots
    visited = {}
    files = []
    layout = {}
    for _ in range(128):
        if not pending:
            return {"files": sorted(files), "layout": [[p] + layout[p] for p in sorted(layout)]}
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
                pending.extend([str(p) for p in physical.readdir(watch = "yes")])
            else:
                ctx.watch(canonical)
                files.append(canonical)
    fail("SDK input directory traversal exceeded 128 levels.")

sdk_inventory_inputs = struct(manifest = _manifest)
