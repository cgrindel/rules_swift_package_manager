"""Definition for collect_export_declaration macro."""

load(":collection_results.bzl", "collection_results")
load(":declarations.bzl", "declarations")
load(":errors.bzl", "errors")
load(":tokens.bzl", "tokens", ops = "operators", rws = "reserved_words", tts = "token_types")

def collect_export_declaration(parsed_tokens):
    """Collect export declaration.

    Spec: https://clang.llvm.org/docs/Modules.html#export-declaration

    Syntax:
        export-declaration:
          export wildcard-module-id

        wildcard-module-id:
          identifier
          '*'
          identifier '.' wildcard-module-id

    Args:
        parsed_tokens: A `list` of tokens.

    Returns:
        A `tuple` where the first item is the collection result and the second is an
        error `struct` as returned from errors.create().
    """
    tlen = len(parsed_tokens)
    consumed_count = 0

    _export_token, err = tokens.get_as(parsed_tokens, 0, tts.reserved, rws.export, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    wildcard = False
    identifiers = []
    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1

        # Get next token
        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        if tokens.is_a(token, tts.operator, ops.asterisk):
            wildcard = True
            break

        elif tokens.is_a(token, tts.identifier):
            identifiers.append(token.value)

        elif tokens.is_a(token, tts.period):
            pass

        elif tokens.is_a(token, tts.newline):
            break

        else:
            return None, errors.new(
                "Unexpected token collecting export declaration. token: %s" % (token),
            )

    decl = declarations.export(
        identifiers = identifiers,
        wildcard = wildcard,
    )
    return collection_results.new([decl], consumed_count), None
