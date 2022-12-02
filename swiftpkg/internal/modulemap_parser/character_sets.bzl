"""Definition for character_sets module."""

load("@bazel_skylib//lib:sets.bzl", "sets")

_whitespaces = sets.make([
    " ",  # space
    "\t",  # horizontal tab
    # "\\v",  # vertical tab
    # "\\b",  # backspace
])

_newlines = sets.make([
    "\n",  # line feed
    "\r",  # carriage return
    # "\\f",  # form feed
])

_non_zero_decimal_digits = sets.make([
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
])

_decimal_digits = sets.union(_non_zero_decimal_digits, sets.make(["0"]))

_lowercase_letters = sets.make([
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
])

_uppercase_letters = sets.make([
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
])

_letters = sets.union(_lowercase_letters, _uppercase_letters)

_c99_operators = sets.make(["*"])

_c99_identifier_beginning_characters = sets.union(_letters, sets.make(["_"]))

_c99_identifier_characters = sets.union(_c99_identifier_beginning_characters, _decimal_digits)

_c99_hexadecimal_characters = sets.union(_decimal_digits, sets.make([
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
]))

_c99_number_characters = sets.union(
    _decimal_digits,
    _c99_hexadecimal_characters,
    sets.make(["x", "X", "."]),
)

character_sets = struct(
    whitespaces = _whitespaces,
    newlines = _newlines,
    lowercase_letters = _lowercase_letters,
    uppercase_letters = _uppercase_letters,
    letters = _letters,
    non_zero_decimal_digits = _non_zero_decimal_digits,
    decimal_digits = _decimal_digits,
    c99_operators = _c99_operators,
    c99_identifier_beginning_characters = _c99_identifier_beginning_characters,
    c99_identifier_characters = _c99_identifier_characters,
    c99_hexadecimal_characters = _c99_hexadecimal_characters,
    c99_number_characters = _c99_number_characters,
)
