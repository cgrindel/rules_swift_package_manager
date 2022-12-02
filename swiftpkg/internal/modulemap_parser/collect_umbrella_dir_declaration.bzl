"""Definition for collect_umbrella_dir_declaration."""

load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

def collect_umbrella_dir_declaration(parsed_tokens):
    """Collect an umbrella directory declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#umbrella-directory-declaration

    Syntax:
        umbrella-dir-declaration:
          umbrella string-literal

    Args:
        parsed_tokens: A `list` of tokens.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)
    consumed_count = 0

    _umbrella_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.umbrella, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    path_token, err = tokens.get_as(parsed_tokens, 1, tts.string_literal, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    decl = declarations.umbrella_directory(path_token.value)
    return collection_results.new([decl], consumed_count), None
