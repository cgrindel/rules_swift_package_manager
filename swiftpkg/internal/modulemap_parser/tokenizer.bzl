"""Definition for tokenizer."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":character_sets.bzl", "character_sets")
load(":tokens.bzl", "reserved_words_set", "tokens")

def _tokenizer_result(tokens, errors = []):
    return struct(
        tokens = tokens,
        errors = errors,
    )

def _collection_result(chars = [], count = None, errors = []):
    """Creates a collection result `struct`.

    Args:
        chars: A `list` of the tokens that were collected.
        count: The count of characters collected.
        errors: A `list` of errors that were found.

    Returns:
        A `struct` representing the data that was collected.
    """
    if not count:
        count = len(chars)
    return struct(
        chars = chars,
        count = count,
        value = "".join(chars),
        errors = errors,
    )

def _error(char, msg):
    return struct(
        char = char,
        msg = msg,
    )

def _collect_chars_in_set(chars, target_set):
    collected_chars = []
    for char in chars:
        if sets.contains(target_set, char):
            collected_chars.append(char)
        else:
            break

    return _collection_result(
        chars = collected_chars,
    )

def _collect_string_literal(chars):
    collected_chars = []

    # We know that the first character is the double quote.
    for char in chars[1:]:
        if char == "\"":
            break
        collected_chars.append(char)

    return _collection_result(
        chars = collected_chars,
        count = len(collected_chars) + 2,  # Need to account for string delimiters.
    )

def _tokenize(text):
    """Collects the tokens from the specified text.

    Args:
        text: A `string` from which the tokens are derived.

    Returns:
        A `list` of tokens.
    """
    collected_tokens = []
    errors = []

    chars = text.elems()
    chars_len = len(chars)

    skip_ahead = 0
    for idx in range(chars_len):
        if skip_ahead > 0:
            skip_ahead -= 1
            continue

        collect_result = None
        char = chars[idx]
        if char == "{":
            collected_tokens.append(tokens.curly_bracket_open())

        elif char == "}":
            collected_tokens.append(tokens.curly_bracket_close())

        elif char == "[":
            collected_tokens.append(tokens.square_bracket_open())

        elif char == "]":
            collected_tokens.append(tokens.square_bracket_close())

        elif char == "!":
            collected_tokens.append(tokens.exclamation_point())

        elif char == ",":
            collected_tokens.append(tokens.comma())

        elif char == ".":
            collected_tokens.append(tokens.period())

        elif char == "\"":
            collect_result = _collect_string_literal(chars[idx:])

            collected_tokens.append(tokens.string_literal(collect_result.value))

        elif sets.contains(character_sets.whitespaces, char):
            pass

        elif sets.contains(character_sets.newlines, char):
            collect_result = _collect_chars_in_set(chars[idx:], character_sets.newlines)
            collected_tokens.append(tokens.newline())

        elif sets.contains(character_sets.c99_identifier_beginning_characters, char):
            collect_result = _collect_chars_in_set(
                chars[idx:],
                character_sets.c99_identifier_characters,
            )
            if sets.contains(reserved_words_set, collect_result.value):
                id_token = tokens.reserved(collect_result.value)
            else:
                id_token = tokens.identifier(collect_result.value)
            collected_tokens.append(id_token)

        elif sets.contains(character_sets.decimal_digits, char):
            # NOTE: This is some weak sauce. This implementation is relying on Starlark to parse
            # whatever was specified.
            collect_result = _collect_chars_in_set(chars[idx:], character_sets.c99_number_characters)
            num_str = collect_result.value.lower()
            if num_str.find(".") > -1:
                num_token = tokens.float_literal(float(num_str))
            elif num_str.startswith("0x"):
                num_token = tokens.integer_literal(int(num_str, base = 16))
            elif num_str.startswith("0") and len(num_str) > 1 and sets.contains(character_sets.decimal_digits, num_str[1:2]):
                num_token = tokens.integer_literal(int(num_str, base = 8))
            else:
                num_token = tokens.integer_literal(int(num_str))
            collected_tokens.append(num_token)

        elif sets.contains(character_sets.c99_operators, char):
            # If we implement more than just asterisk for operators, this will need to be
            # revisited.
            collect_result = _collect_chars_in_set(chars[idx:], character_sets.c99_operators)
            collected_tokens.append(tokens.operator("".join(collect_result.chars)))

        else:
            # Did not recognize the char. Keep trucking.
            err = _error(char, "Unrecognized character")
            errors.append(err)
            idx += 1

        if collect_result:
            skip_ahead = collect_result.count - 1

    return _tokenizer_result(collected_tokens, errors = errors)

tokenizer = struct(
    tokenize = _tokenize,
    result = _tokenizer_result,
)
