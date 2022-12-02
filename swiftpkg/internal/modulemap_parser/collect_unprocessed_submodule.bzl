"""Module for colleccting unprocessed submodule tokens"""

load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations")
load(":errors.bzl", "errors")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

def collect_unprocessed_submodule(parsed_tokens, prefix_tokens = []):
    """Collect the submodule tokens for later processing.

    https://clang.llvm.org/docs/Modules.html#submodule-declaration

    Args:
        parsed_tokens: A `list` of tokens.
        prefix_tokens: A `list` of tokens that have already been collected, but not applied.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)
    submodule_tokens = []
    consumed_count = 0

    _module_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.module, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1
    submodule_tokens.append(_module_token)

    bracket_level = 0

    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1

        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        if tokens.is_a(token, tts.curly_bracket_open):
            bracket_level += 1

        if tokens.is_a(token, tts.curly_bracket_close):
            bracket_level -= 1
            if bracket_level == 0:
                submodule_tokens.append(token)
                break
            elif bracket_level < 0:
                return None, errors.new(
                    "Encountered a curly bracket close without a corresponding open while collecting unprocessed submodule. tokens: %s" %
                    (parsed_tokens),
                )

        submodule_tokens.append(token)

    decl = declarations.unprocessed_submodule(tokens = submodule_tokens, prefix_tokens = prefix_tokens)
    return collection_results.new([decl], consumed_count), None
