"""Defintion for collect_module."""

load(":collect_module_members.bzl", "collect_module_members")
load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations")
load(":errors.bzl", "errors")
load(":module_declarations.bzl", "module_declarations")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

# MARK: - Attribute Collection

def _collect_attribute(parsed_tokens):
    """Collect a module attribute.

    Spec: https://clang.llvm.org/docs/Modules.html#attributes

    Syntax:
        attributes:
          attribute attributesopt

        attribute:
          '[' identifier ']'

    Args:
        parsed_tokens: A `list` of tokens.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)

    _open_token, err = tokens.get_as(parsed_tokens, 0, tts.square_bracket_open, count = tlen)
    if err != None:
        return None, err

    attrib_token, err = tokens.get_as(parsed_tokens, 1, tts.identifier, count = tlen)
    if err != None:
        return None, err

    _open_token, err = tokens.get_as(parsed_tokens, 2, tts.square_bracket_close, count = tlen)
    if err != None:
        return None, err

    return collection_results.new([attrib_token.value], 3), None

# MARK: - Module Collection

def _process_module_tokens(parsed_tokens, prefix_tokens, is_submodule):
    """Process module and submodule tokens

    Spec: https://clang.llvm.org/docs/Modules.html#module-declaration

    Syntax:
        explicitopt frameworkopt module module-id attributesopt '{' module-member* '}'

    Args:
        parsed_tokens: A `list` of tokens.
        prefix_tokens: A `list` of tokens that have already been collected, but not applied.
        is_submodule: A `bool` that designates whether the module is a child of another module.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    explicit = False
    framework = False
    attributes = []
    members = []
    consumed_count = 0

    tlen = len(parsed_tokens)

    # Process the prefix tokens
    for token in prefix_tokens:
        if token.type == tts.reserved and token.value == rws.explicit:
            if not is_submodule:
                return None, errors.new("The explicit qualifier can only exist on submodules.")
            explicit = True

        elif token.type == tts.reserved and token.value == rws.framework:
            framework = True

        else:
            return None, errors.new(
                "Unexpected prefix token collecting module declaration. token: %s" % (token),
            )

    _module_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.module, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    module_id_token, err = tokens.get_as(parsed_tokens, 1, tts.identifier, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    # Collect the attributes and module members
    skip_ahead = 0
    collect_result = None
    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1
        if skip_ahead > 0:
            skip_ahead -= 1
            continue

        collect_result = None
        err = None

        # Get next token
        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        # Process the token
        if tokens.is_a(token, tts.curly_bracket_open):
            collect_result, err = collect_module_members(parsed_tokens[idx:])
            if err != None:
                return None, err
            members.extend(collect_result.declarations)
            consumed_count += collect_result.count - 1
            break

        elif tokens.is_a(token, tts.square_bracket_open):
            collect_result, err = _collect_attribute(parsed_tokens[idx:])
            if err != None:
                return None, err
            attributes.extend(collect_result.declarations)

        else:
            return None, errors.new(
                "Unexpected token collecting attributes and module members. token: %s" % (token),
            )

        # Handle index advancement.
        if collect_result:
            skip_ahead = collect_result.count - 1

    # Create the declaration
    decl = declarations.module(
        module_id = module_id_token.value,
        explicit = explicit,
        framework = framework,
        attributes = attributes,
        members = members,
    )
    return collection_results.new([decl], consumed_count), None

def collect_module(parsed_tokens, prefix_tokens = []):
    """Collect top-level module declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#module-declaration

    Syntax:
        explicitopt frameworkopt module module-id attributesopt '{' module-member* '}'

    Args:
        parsed_tokens: A `list` of tokens.
        prefix_tokens: A `list` of tokens that have already been collected, but not applied.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """

    # buildifier: disable=uninitialized
    def _get_single_decl(collect_result):
        if len(collect_result.declarations) != 1:
            return None, errors.new(
                "Expect a single module declaration but found {decl_count}.".format(
                    decl_count = len(collect_result.declarations),
                ),
            )

        return collect_result.declarations[0], None

    # buildifier: disable=uninitialized
    def _update_module_decl(top_module_decl, path, collect_result):
        module_decl, err = _get_single_decl(collect_result)
        if err != None:
            return None, err
        if top_module_decl == None:
            new_top_module_decl = module_decl
        else:
            new_top_module_decl, err = module_declarations.replace_member(
                root_module = top_module_decl,
                path = path,
                new_member = module_decl,
            )
            if err != None:
                return None, err

        return new_top_module_decl, module_decl, None

    top_module_decl = None
    top_collect_result = None
    module_tokens_to_process = [
        ([], declarations.unprocessed_submodule(parsed_tokens, prefix_tokens)),
    ]

    # NOTE: Since recursive processing is not supported in Starlark, we need to
    # process different levels of submodules in a loop.
    #
    # The gist of the algorithm is that a set of tokens will result in a
    # `declarations.module()` value that may have 0 or more members. If a
    # module contains a submodule, it will be represented by
    # `declarations.unprocessed_submodule()` value. When an unprocessed
    # submodule is found, it is added to the `module_tokens_to_process` `list`.
    # Processing continues until the `module_tokens_to_process` `list` is empty
    # or 100 iterations have occurred.

    for _iteration in range(100):
        if len(module_tokens_to_process) == 0:
            break

        cur_idx_path, unprocessed_tokens = module_tokens_to_process.pop(0)
        collect_result, err = _process_module_tokens(
            parsed_tokens = unprocessed_tokens.tokens,
            prefix_tokens = unprocessed_tokens.prefix_tokens,
            is_submodule = (top_collect_result != None),
        )
        if err != None:
            return None, err

        if top_collect_result == None:
            top_collect_result = collect_result

        top_module_decl, module_decl, err = _update_module_decl(
            top_module_decl,
            cur_idx_path,
            collect_result,
        )
        if err != None:
            return None, err

        for idx, member in enumerate(module_decl.members):
            if member.decl_type != declarations.types.unprocessed_submodule:
                continue
            submodule_idx_path = cur_idx_path + [idx]
            module_tokens_to_process.append((submodule_idx_path, member))

    return collection_results.new(
        declarations = [top_module_decl],
        count = top_collect_result.count,
    ), None
