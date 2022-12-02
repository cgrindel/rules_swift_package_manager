"""Module for managing module declarations"""

load(":declarations.bzl", "declarations")
load(":errors.bzl", "errors")

def _is_a_module(decl):
    """Determines whether the provided declaration is a module or inferred submodule.

    Args:
        decl: A `struct` as returned by one of the `declarations` functions.

    Returns:
        A `bool` value. `True` if it is module or inferred submodule. Otherwise, `False`.
    """
    return decl.decl_type in [
        declarations.types.module,
        declarations.types.inferred_submodule,
    ]

def _check_root_module_and_path(root_module, path):
    """Performs common checks on `root_module` and `path` arguments.

    Args:
        root_module: A `struct` as returned by `declarations.module()`.
        path: A `list` of `int` values representing member index values.

    Returns:
        An error `struct` as returned from `errors.create()` or None if no errors.
    """
    if root_module == None:
        return errors.new("The `root_module` was `None`. path: {}".format(path))
    if not _is_a_module(root_module):
        return errors.new("The `root_module` is not a module. {}".format(root_module))
    if path == []:
        return errors.new("The `path` cannot be empty.")
    return None

def _get_member(root_module, path):
    """Returns the member declaration at the given path.

    Args:
        root_module: A `struct` as returned by `declarations.module()`.
        path: A `list` of `int` values representing member index values.

    Returns:
        A `tuple` where the first item is the member declaration and the second
        is an error `struct` as returned from `errors.create()`.
    """
    err = _check_root_module_and_path(root_module, path)
    if err != None:
        return None, err

    member = None
    cur_module = root_module
    for idx in path:
        if cur_module == None:
            return None, errors.new("Invalid path. root_module: {}, path: {}".format(
                root_module,
                path,
            ))
        member = cur_module.members[idx]
        cur_module = member if _is_a_module(member) else None
    return member, None

def _replace_member(root_module, path, new_member):
    """Replaces the member declaration identified by the path with another \
    member.

    Args:
        root_module: A `struct` as returned by `declarations.module()`.
        path: A `list` of `int` values representing member index values.
        new_member: A `struct` as returned by a function from the
            `declarations` module.

    Returns:
        A `tuple` where the first item is a copy of the `root_module` with the
        `new_member` and the second item is an error `struct` as returned from
        `errors.create()`.
    """
    path_len = len(path)

    err = _check_root_module_and_path(root_module, path)
    if err != None:
        return None, err
    if new_member == None:
        return None, errors.new("The `new_member` argument was `None`.")

    # Collect the parent modules
    parent_modules = [root_module]
    for idx in range(1, path_len, 1):
        member, err = _get_member(root_module, path[:idx])
        if err != None:
            return None, err
        if not _is_a_module(member):
            return None, errors.new("Expected a module. {}".format(member))
        parent_modules.append(member)

    cur_new_member = new_member
    for offset in range(-1, -(len(parent_modules) + 1), -1):
        parent_module = parent_modules[offset]
        member_idx = path[offset]

        new_members = list(parent_module.members)

        new_members.pop(member_idx)
        new_members.insert(member_idx, cur_new_member)

        cur_new_member, err = declarations.copy_module(
            parent_module,
            members = new_members,
        )

    return cur_new_member, None

module_declarations = struct(
    is_a_module = _is_a_module,
    get_member = _get_member,
    replace_member = _replace_member,
)
