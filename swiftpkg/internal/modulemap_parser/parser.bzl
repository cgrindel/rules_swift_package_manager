"""Definition for parser."""

load(":collect_extern_module.bzl", "collect_extern_module")
load(":collect_module.bzl", "collect_module")
load(":errors.bzl", "errors")
load(":tokenizer.bzl", "tokenizer")
load(":tokens.bzl", rws = "reserved_words", tts = "token_types")

def _parse(text):
    tokenizer_result = tokenizer.tokenize(text)
    if len(tokenizer_result.errors) > 0:
        return None, errors.new("Errors from tokenizer", tokenizer_result.errors)

    parsed_tokens = tokenizer_result.tokens
    tokens_cnt = len(parsed_tokens)

    collected_decls = []
    skip_ahead = 0
    prefix_tokens = []
    for idx in range(tokens_cnt):
        if skip_ahead > 0:
            skip_ahead -= 1
            continue

        token = parsed_tokens[idx]
        collect_result = None
        err = None

        if token.type == tts.newline:
            pass

        elif token.type == tts.reserved:
            if token.value == rws.extern:
                collect_result, err = collect_extern_module(parsed_tokens[idx:])

            elif token.value == rws.module:
                collect_result, err = collect_module(
                    parsed_tokens[idx:],
                    prefix_tokens = prefix_tokens,
                )
                prefix_tokens = []

            else:
                prefix_tokens.append(token)

        else:
            prefix_tokens.append(token)

        if err:
            return None, err

        if collect_result:
            collected_decls.extend(collect_result.declarations)
            skip_ahead = collect_result.count - 1

    return collected_decls, None

parser = struct(
    parse = _parse,
)
