"""Definition for collect_module_members."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":collect_export_declaration.bzl", "collect_export_declaration")
load(":collect_header_declaration.bzl", "collect_header_declaration")
load(":collect_link_declaration.bzl", "collect_link_declaration")
load(":collect_umbrella_dir_declaration.bzl", "collect_umbrella_dir_declaration")
load(":collect_unprocessed_submodule.bzl", "collect_unprocessed_submodule")
load(":collection_results.bzl", "collection_results")
load(":errors.bzl", "errors")
load(":tokens.bzl", "tokens", rws = "reserved_words", tts = "token_types")

_unsupported_module_members = sets.make([
    rws.config_macros,
    rws.conflict,
    rws.requires,
    rws.use,
])

def collect_module_members(parsed_tokens):
    """Collect module members from the parsed tokens.

    Args:
        parsed_tokens: A `list` of tokens.

    Returns:
        Collection results.
    """
    tlen = len(parsed_tokens)
    members = []
    consumed_count = 0

    _open_members_token, err = tokens.get_as(parsed_tokens, 0, tts.curly_bracket_open, count = tlen)
    if err != None:
        return None, err
    consumed_count += 1

    skip_ahead = 0
    collect_result = None
    prefix_tokens = []
    for idx in range(consumed_count, tlen - consumed_count):
        consumed_count += 1
        if skip_ahead > 0:
            skip_ahead -= 1
            continue

        collect_result = None

        # Get next token
        token, err = tokens.get(parsed_tokens, idx, count = tlen)
        if err != None:
            return None, err

        # Process token

        if tokens.is_a(token, tts.curly_bracket_close):
            if len(prefix_tokens) > 0:
                return None, errors.new(
                    "Unexpected prefix tokens found at end of module member block. tokens: %s" %
                    (prefix_tokens),
                )
            break

        elif tokens.is_a(token, tts.newline):
            if len(prefix_tokens) > 0:
                return None, errors.new(
                    "Unexpected prefix tokens found before end of line. tokens: %s" % (prefix_tokens),
                )

        elif tokens.is_a(token, tts.reserved, rws.umbrella):
            # The umbrella word can appear for umbrella headers or umbrella directories.
            # If the next token is header, then it is an umbrella header. Otherwise, it is an umbrella
            # directory.
            next_idx = idx + 1
            next_token, err = tokens.get(parsed_tokens, next_idx, count = tlen)
            if err != None:
                return None, err
            if tokens.is_a(next_token, tts.reserved, rws.header):
                prefix_tokens.append(token)

            else:
                if len(prefix_tokens) > 0:
                    return None, errors.new(
                        "Unexpected prefix tokens found before end of line. tokens: %" %
                        (prefix_tokens),
                    )
                collect_result, err = collect_umbrella_dir_declaration(parsed_tokens[idx:])

        elif tokens.is_a(token, tts.reserved, rws.header):
            collect_result, err = collect_header_declaration(parsed_tokens[idx:], prefix_tokens)
            prefix_tokens = []

        elif tokens.is_a(token, tts.reserved, rws.export):
            collect_result, err = collect_export_declaration(parsed_tokens[idx:])

        elif tokens.is_a(token, tts.reserved, rws.link):
            collect_result, err = collect_link_declaration(parsed_tokens[idx:])

        elif tokens.is_a(token, tts.reserved) and sets.contains(_unsupported_module_members, token.value):
            return None, errors.new("Unsupported module member token. token: %s" % (token))

        elif tokens.is_a(token, tts.reserved, rws.module):
            collect_result, err = collect_unprocessed_submodule(parsed_tokens[idx:], prefix_tokens)
            prefix_tokens = []

        else:
            # Store any unrecognized tokens as prefix tokens to be processed later
            prefix_tokens.append(token)

        # Handle index advancement.
        if err != None:
            return None, err
        if collect_result:
            members.extend(collect_result.declarations)
            skip_ahead = collect_result.count - 1

    return collection_results.new(members, consumed_count), None
