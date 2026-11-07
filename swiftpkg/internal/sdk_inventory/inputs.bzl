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
            ctx.watch(logical)
            if not path.exists:
                layout[logical] = [None, "missing"]
                continue
            canonical = str(path.realpath)
            layout[logical] = [canonical, "directory" if path.is_dir else "file"]
            if canonical in visited:
                continue
            visited[canonical] = True
            physical = ctx.path(canonical)
            if physical.is_dir:
                pending.extend([str(p) for p in physical.readdir(watch = "yes")])
            else:
                ctx.watch(canonical)
                files.append(canonical)
    fail("SDK input directory traversal exceeded 128 levels.")

sdk_inventory_inputs = struct(manifest = _manifest)
