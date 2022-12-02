"""Definition for collect_link_declaration."""

load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations")
load(":errors.bzl", "errors")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

def collect_link_declaration(parsed_tokens):
    """Collect a link declaration.

    Syntax:
        link-declaration:
          link frameworkopt string-literal

    Args:
        parsed_tokens: A `list` of tokens.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)
    consumed_count = 0

    _link_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.link, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    framework = False
    library_name = None
    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1

        # Get next token
        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        if tokens.is_a(token, tts.reserved, rws.framework):
            framework = True

        elif tokens.is_a(token, tts.string_literal):
            library_name = token.value
            break

        else:
            return None, errors.new(
                "Unexpected token collecting link declaration. token: %s" % (token),
            )

    if library_name == None:
        return None, errors.new(
            "Expected a library/framework name for the link declaration.",
        )

    decl = declarations.link(
        library_name,
        framework = framework,
    )
    return collection_results.new([decl], consumed_count), None
