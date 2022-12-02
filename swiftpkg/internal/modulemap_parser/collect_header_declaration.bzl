"""Definition for collect_header_declaration."""

load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations", dts = "declaration_types")
load(":errors.bzl", "errors")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

def collect_header_declaration(parsed_tokens, prefix_tokens):
    """Collect a header declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#header-declaration

    Syntax:
        header-declaration:
          privateopt textualopt header string-literal header-attrsopt
          umbrella header string-literal header-attrsopt
          exclude header string-literal header-attrsopt

        header-attrs:
          '{' header-attr* '}'

        header-attr:
          size integer-literal
          mtime integer-literal

    Args:
        parsed_tokens: A `list` of tokens.
        prefix_tokens: A `list` of tokens that have been consumed but not yet processed.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)

    decl_type = dts.single_header
    private = False
    textual = False

    for token in prefix_tokens:
        if tokens.is_a(token, tts.reserved, rws.umbrella):
            decl_type = dts.umbrella_header
        elif tokens.is_a(token, tts.reserved, rws.exclude):
            decl_type = dts.exclude_header
        elif tokens.is_a(token, tts.reserved, rws.private):
            private = True
        elif tokens.is_a(token, tts.reserved, rws.textual):
            textual = True
        else:
            return None, errors.new(
                "Unexpected token processing header declaration prefix tokens. token: %s" %
                (token),
            )

    consumed_count = 0

    _header_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.header, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    path_token, err = tokens.get_as(parsed_tokens, 1, tts.string_literal, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    consume_header_attribs_section = False
    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1

        # Get next token
        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        if consume_header_attribs_section:
            # Consume tokens until we find the end of the section
            if tokens.is_a(token, tts.curly_bracket_close):
                consume_header_attribs_section = False

        elif tokens.is_a(token, tts.newline):
            break

        elif tokens.is_a(token, tts.curly_bracket_open):
            # Ignoring header attributes for now.
            consume_header_attribs_section = True

        else:
            return None, errors.new(
                "Unexpected token processing header declaration. token: %s" % (token),
            )

    if decl_type == dts.single_header:
        decl = declarations.single_header(path_token.value, private = private, textual = textual)
    elif decl_type == dts.umbrella_header:
        decl = declarations.umbrella_header(path_token.value)
    elif decl_type == dts.exclude_header:
        decl = declarations.exclude_header(path_token.value)
    else:
        return None, errors.new("Unrecognized declaration type. %s" % (decl_type))

    return collection_results.new([decl], consumed_count), None
