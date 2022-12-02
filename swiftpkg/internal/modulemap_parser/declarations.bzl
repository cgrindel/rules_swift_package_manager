"""Definition for declarations module."""

load(":errors.bzl", "errors")

# MARK: - Module Declarations

_TYPES = struct(
    module = "module",
    inferred_submodule = "inferred_submodule",
    extern_module = "extern_module",
    single_header = "single_header",
    umbrella_header = "umbrella_header",
    exclude_header = "exclude_header",
    umbrella_directory = "umbrella_directory",
    export = "export",
    link = "link",
    # An unprocessed_submodule contains the tokens of the submodule. They will
    # be processed later because Starlark does not allow recursion.
    unprocessed_submodule = "unprocessed_submodule",
)

def _create_module_decl(module_id, explicit = False, framework = False, attributes = [], members = []):
    """Create a module declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#module-declaration

    Args:
        module_id: A `string` that identifies the module.
        explicit: A `bool` that designates the module as explicit.
        framework: A `bool` that designzates the module as being Darwin framework.
        attributes: A `list` of `string` values specified as attrivutes.
        members: A `list` of the module members.

    Returns:
        A `struct` representing a module declaration.
    """
    return struct(
        decl_type = _TYPES.module,
        module_id = module_id,
        explicit = explicit,
        framework = framework,
        attributes = attributes,
        members = members,
    )

def _create_inferred_submodule_decl(explicit = False, framework = False, attributes = [], members = []):
    return struct(
        decl_type = _TYPES.inferred_submodule,
        explicit = explicit,
        framework = framework,
        attributes = attributes,
        members = members,
    )

def _create_extern_module_decl(module_id, definition_path):
    """Create an extern module declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#module-declaration

    Args:
        module_id: A `string` that identifies the module.
        definition_path: The path (`string`) to a file that contains the definition for the
                         identified module.

    Returns:
        A `struct` representing an extern module declaration.
    """
    return struct(
        decl_type = _TYPES.extern_module,
        module_id = module_id,
        definition_path = definition_path,
    )

def _create_unprocessed_submodule(tokens, prefix_tokens):
    """Create an unprocessed submodule declaration.

    Args:
        tokens: A `list` of tokens.
        prefix_tokens: A `list` of tokens that have already been collected, but not applied.

    Returns:
        A `struct` representing an unprocessed submodule declaration.
    """
    return struct(
        decl_type = _TYPES.unprocessed_submodule,
        tokens = tokens,
        prefix_tokens = prefix_tokens,
    )

def _copy_module(module, members):
    """Copies the provided module or inferred submodule declaration and \
    replaces its members with the provided members.

    Args:
        module: A `struct` as returned by `declarations.module()` or
            `declarations.inferred_submodule()`.
        members: A `list` of  member declarations.

    Returns:
        A `tuple` where the the first item is the copied declaration and the
        second item is an error `struct` as returned from `errors.create()`.
    """
    if module.decl_type == _TYPES.module:
        return _create_module_decl(
            module_id = module.module_id,
            explicit = module.explicit,
            framework = module.framework,
            attributes = module.attributes,
            members = members,
        ), None
    elif module.decl_type == _TYPES.inferred_submodule:
        return _create_inferred_submodule_decl(
            explicit = module.explicit,
            framework = module.framework,
            attributes = module.attributes,
            members = members,
        ), None
    return None, errors.new(
        "Unrecognized declaration type in `module_declarations.copy_module`.",
    )

# MARK: - Module Member Declarations

def _create_header_attributes(size = None, mtime = None):
    """Creates a struct representing header attributes.

    Spec: https://clang.llvm.org/docs/Modules.html#header-declaration

    Args:
        size: An `int` specifying the size attribute value.
        mtime: An `int` specifying the mtime attribute value.

    Returns:
        A `struct` representing header attribute values.
    """
    return struct(
        size = size,
        mtime = mtime,
    )

def _create_single_header(path, private = False, textual = False, attribs = None):
    """Creates a `struct` representing a single header declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#header-declaration

    Args:
        path: A `string` specifying the path to the header.
        private: A `bool` specifying whether it is private.
        textual: A `bool` specifying whether it is a textual header.
        attribs: A `struct` as returned from `declarations.header_attribs()` representing the
                 header attributes.

    Returns:
        A `struct` representing a single
    """
    return struct(
        decl_type = _TYPES.single_header,
        path = path,
        private = private,
        textual = textual,
        attribs = attribs,
    )

def _create_umbrella_header(path, attribs = None):
    """Creates a `struct` representing an umbrella header declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#header-declaration

    Args:
        path: A `string` specifying the path to the header.
        attribs: A `struct` as returned from `declarations.header_attribs()` representing the
                 header attributes.

    Returns:
        A `struct` representing an umbrella header declaration.
    """
    return struct(
        decl_type = _TYPES.umbrella_header,
        path = path,
        attribs = attribs,
    )

def _create_exclude_header(path, attribs = None):
    """Creates a `struct` representing an exclude header declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#header-declaration

    Args:
        path: A `string` specifying the path to the header.
        attribs: A `struct` as returned from `declarations.header_attribs()` representing the
                 header attributes.

    Returns:
        A `struct` representing an exclude header declaration.
    """
    return struct(
        decl_type = _TYPES.exclude_header,
        path = path,
        attribs = attribs,
    )

def _create_umbrella_directory(path):
    """Creates a `struct` representing an umbrella directory declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#umbrella-directory-declaration

    Args:
        path: A `string` specifying the path to the directory with the header files.

    Returns:
        A `struct` representing an umbrella directory declaration.
    """
    return struct(
        decl_type = _TYPES.umbrella_directory,
        path = path,
    )

def _create_export(identifiers = [], wildcard = False):
    """Creates a `struct` representing an export declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#umbrella-directory-declaration

    Args:
        identifiers: A `list` of `string` values.
        wildcard: A `bool` indicating whether it is a wildcard at the end of the identifiers.

    Returns:
        A `struct` representing an export declaration.
    """
    return struct(
        decl_type = _TYPES.export,
        identifiers = identifiers,
        wildcard = wildcard,
    )

def _create_link(name, framework = False):
    """Creates a `struct` representing a link declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#link-declaration

    Args:
        name: The name of the library or framework as a `string`.
        framework: A `bool` indicating whether the link is to a framework.

    Returns:
        A `struct` representing a link declaration.
    """
    return struct(
        decl_type = _TYPES.link,
        name = name,
        framework = framework,
    )

# MARK: - Namespaces

declaration_types = _TYPES

declarations = struct(
    copy_module = _copy_module,
    exclude_header = _create_exclude_header,
    export = _create_export,
    extern_module = _create_extern_module_decl,
    header_attribs = _create_header_attributes,
    inferred_submodule = _create_inferred_submodule_decl,
    link = _create_link,
    module = _create_module_decl,
    single_header = _create_single_header,
    types = _TYPES,
    umbrella_directory = _create_umbrella_directory,
    umbrella_header = _create_umbrella_header,
    unprocessed_submodule = _create_unprocessed_submodule,
)
