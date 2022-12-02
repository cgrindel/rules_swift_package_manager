"""Definition for tokens module."""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//lib:types.bzl", "types")
load(":errors.bzl", "errors")

# MARK: - Token Creation Functions

def _is_valid_value(value_type_or_set, value):
    """Returns a boolean indicating whether the specified value is valid for the specified value type.

    Args:
        value_type_or_set: If this is a string, then it is considered to be a string type as returned
                           by type(). Otherwise, it is a set as returned by sets.make() which contains
                           the acceptable values.
        value: The value being evaluated.

    Returns:
        True if the value is valid. Otherwise, false.
    """
    if types.is_string(value_type_or_set):
        return type(value) == value_type_or_set
    return sets.contains(value_type_or_set, value)

def _create_token_type(name, value_type_or_set = type(None)):
    """Creates a token type struct.

    Args:
        name: The name of the type.
        value_type_or_set: The type name or set of acceptable values.

    Returns:
        A `struct` representing the token type.
    """
    _token_types_validation[name] = struct(
        value_type = value_type_or_set,
        is_valid_value_fn = partial.make(_is_valid_value, value_type_or_set),
    )
    return name

def _create(token_type_name, value = None):
    """Create a token of the specified type.

    Args:
        token_type_name: The token type or the name of the token type.
        value: Optional. The value associated with the token.

    Returns:
        A `struct` representing the token.
    """
    validation_info = _token_types_validation[token_type_name]
    if not validation_info:
        fail("Invalid token type name", token_type_name)

    if not partial.call(validation_info.is_valid_value_fn, value):
        fail("Invalid value for token type", token_type_name, value)

    return struct(
        type = token_type_name,
        value = value,
    )

# MARK: - Reserved Words

_reserved_words = struct(
    config_macros = "config_macros",
    conflict = "conflict",
    exclude = "exclude",
    explicit = "explicit",
    export = "export",
    export_as = "export_as",
    extern = "extern",
    framework = "framework",
    header = "header",
    link = "link",
    module = "module",
    private = "private",
    requires = "requires",
    textual = "textual",
    umbrella = "umbrella",
    use = "use",
)
_reserved_words_dict = structs.to_dict(_reserved_words)
_reserved_words_set = sets.make([_reserved_words_dict[k] for k in _reserved_words_dict])

# MARK: - Operators

_operators = struct(
    asterisk = "*",
)

# NOTE: This is meant to be a set of the operators not a set of the operator characters.
# For instance, operator characters could be ["*", "=", "+"] while the list of operators
# could be ["*", "+", "+=", "="].
_operators_set = sets.make(["*"])

# MARK: - Token Types

_token_types_validation = dict()

_token_types = struct(
    reserved = _create_token_type("reserved", _reserved_words_set),
    identifier = _create_token_type("identifier", "string"),
    string_literal = _create_token_type("string_literal", "string"),
    integer_literal = _create_token_type("integer_literal", "int"),
    float_literal = _create_token_type("float_literal", "float"),
    comment = _create_token_type("comment", "string"),
    operator = _create_token_type("operator", _operators_set),
    curly_bracket_open = _create_token_type("curly_bracket_open"),
    curly_bracket_close = _create_token_type("curly_bracket_close"),
    newline = _create_token_type("newline"),
    square_bracket_open = _create_token_type("square_bracket_open"),
    square_bracket_close = _create_token_type("square_bracket_close"),
    exclamation_point = _create_token_type("exclamation_point"),
    comma = _create_token_type("comma"),
    period = _create_token_type("period"),
)

def _create_reserved(value):
    return _create(_token_types.reserved, value)

def _create_identifier(value):
    return _create(_token_types.identifier, value)

def _create_string_literal(value):
    return _create(_token_types.string_literal, value)

def _create_integer_literal(value):
    return _create(_token_types.integer_literal, value)

def _create_float_literal(value):
    return _create(_token_types.float_literal, value)

def _create_comment(value):
    return _create(_token_types.comment, value)

def _create_operator(value):
    return _create(_token_types.operator, value)

def _create_curly_bracket_open():
    return _create(_token_types.curly_bracket_open)

def _create_curly_bracket_close():
    return _create(_token_types.curly_bracket_close)

def _create_newline():
    return _create(_token_types.newline)

def _create_square_bracket_open():
    return _create(_token_types.square_bracket_open)

def _create_square_bracket_close():
    return _create(_token_types.square_bracket_close)

def _create_exclamation_point():
    return _create(_token_types.exclamation_point)

def _create_comma():
    return _create(_token_types.comma)

def _create_period():
    return _create(_token_types.period)

# MARK: - Token Type Functions

def _is_a(token, token_type, value = None):
    """Checks whether the specified token is the specified type and value, if a value is provided.

    Args:
        token: A token `struct`.
        token_type: A `string` specifying the expected token type (i.e. value from `token_types`).
        value: Optional. The expected token value.

    Returns:
        A `bool` value of True if the token is the specified type/value. Otherwise, it returns False.
    """
    if token.type != token_type:
        return False
    if value != None and token.value != value:
        return False
    return True

# MARK: - Token List Functions

def _get_token(tokens, idx, count = None):
    """Returns the token in the list at the specified index.

    Args:
        tokens: A `list` of tokens.
        idx: The current index.
        count: Optional. The number of tokens in the list.

    Returns:
        A `tuple` where the first item is the token and the second item is an error, if any
        occurred.
    """
    if count == None:
        count = len(tokens)
    if idx < 0:
        return None, errors.new("Negative indices are not supported. idx: %s" % (idx))
    if idx >= count:
        return None, errors.new("No more tokens available. count: %s, idx: %s" % (count, idx))
    return tokens[idx], None

def _get_token_as(tokens, idx, token_type, value = None, count = None):
    """Returns the next token in the list if it matches the specified type and, optionally, the specified value.

    Args:
        tokens: A `list` of tokens.
        idx: The current index.
        token_type: The expxected token type `struct`.
        value: Optional. The expected token value.
        count: Optional. The number of tokens in the list.

    Returns:
        A `tuple` where the first item is the next token and the second item is an error, if any
        occurred.
    """
    token, err = _get_token(tokens, idx, count = count)
    if err:
        return None, err
    if token.type != token_type:
        return None, errors.new("Expected type %s, but was %s" % (token_type, token.type))
    if value != None and token.value != value:
        return None, errors.new("Expected value %s, but was %s" % (value, token.value))
    return token, None

# MARK: - Tokens Namespace

reserved_words = _reserved_words
reserved_words_set = _reserved_words_set

operators = _operators

token_types = _token_types

tokens = struct(
    # Token Factories
    reserved = _create_reserved,
    identifier = _create_identifier,
    string_literal = _create_string_literal,
    integer_literal = _create_integer_literal,
    float_literal = _create_float_literal,
    comment = _create_comment,
    operator = _create_operator,
    curly_bracket_open = _create_curly_bracket_open,
    curly_bracket_close = _create_curly_bracket_close,
    newline = _create_newline,
    square_bracket_open = _create_square_bracket_open,
    square_bracket_close = _create_square_bracket_close,
    exclamation_point = _create_exclamation_point,
    comma = _create_comma,
    period = _create_period,

    # Token Functions
    is_a = _is_a,

    # Token List Functions
    get = _get_token,
    get_as = _get_token_as,
)
