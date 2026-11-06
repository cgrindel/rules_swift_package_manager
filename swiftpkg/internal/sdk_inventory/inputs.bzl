"""Watch SDK/compiler inputs once in the shared provider, tolerating directory aliases."""

def _input_files(ctx, roots):
    # SDKs contain directory aliases and cycles (e.g. Ruby.framework headers).
    # watch_tree follows those links without a visited set. Watch physical
    # directories and files once, including directory membership for new modules.
    pending = [ctx.path(root) for root in roots]
    visited = {}
    files = []
    for _ in range(128):
        if not pending:
            return sorted(files)
        current = pending
        pending = []
        for path in current:
            ctx.watch(str(path))
            if not path.exists:
                continue
            canonical = str(path.realpath)
            if canonical in visited:
                continue
            visited[canonical] = True
            physical = ctx.path(canonical)
            if physical.is_dir:
                pending.extend(physical.readdir(watch = "yes"))
            else:
                ctx.watch(canonical)
                files.append(canonical)
    fail("SDK input directory traversal exceeded 128 levels.")

sdk_inventory_inputs = struct(files = _input_files)
