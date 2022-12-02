"""Tests for tokenizer."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/modulemap_parser:tokenizer.bzl", "tokenizer")
load("//swiftpkg/internal/modulemap_parser:tokens.bzl", "tokens")

def _tokenize_test(ctx):
    env = unittest.begin(ctx)

    text = " \t"
    expected = tokenizer.result(
        tokens = [],
    )
    asserts.equals(env, expected, tokenizer.tokenize(text), "consume whitespace")

    text = "{}[]!,."
    expected = tokenizer.result(
        tokens = [
            tokens.curly_bracket_open(),
            tokens.curly_bracket_close(),
            tokens.square_bracket_open(),
            tokens.square_bracket_close(),
            tokens.exclamation_point(),
            tokens.comma(),
            tokens.period(),
        ],
    )
    asserts.equals(env, expected, tokenizer.tokenize(text), "consume no value tokens")

    text = "{\n\r}"
    expected = tokenizer.result(
        tokens = [
            tokens.curly_bracket_open(),
            tokens.newline(),
            tokens.curly_bracket_close(),
        ],
    )
    result = tokenizer.tokenize(text)
    asserts.equals(env, expected, result, "consume multiple new lines")

    text = "{\n}"
    expected = tokenizer.result(
        tokens = [
            tokens.curly_bracket_open(),
            tokens.newline(),
            tokens.curly_bracket_close(),
        ],
    )
    result = tokenizer.tokenize(text)
    asserts.equals(env, expected, result, "consume a single new line")

    text = "a1234 module"
    expected = tokenizer.result(
        tokens = [
            tokens.identifier("a1234"),
            tokens.reserved("module"),
        ],
    )
    result = tokenizer.tokenize(text)
    asserts.equals(env, expected, result, "consume identifiers and reserved words")

    text = "{ \"Hello, World!\" }"
    expected = tokenizer.result(
        tokens = [
            tokens.curly_bracket_open(),
            tokens.string_literal("Hello, World!"),
            tokens.curly_bracket_close(),
        ],
    )
    result = tokenizer.tokenize(text)
    asserts.equals(env, expected, result, "consume string literals")

    text = "1234 0x3 02 12.34"
    expected = tokenizer.result(
        tokens = [
            tokens.integer_literal(1234),
            tokens.integer_literal(0x3),
            tokens.integer_literal(0o2),
            tokens.float_literal(12.34),
        ],
    )
    result = tokenizer.tokenize(text)
    asserts.equals(env, expected, result, "consume string literals")

    return unittest.end(env)

tokenize_test = unittest.make(_tokenize_test)

def tokenizer_test_suite():
    return unittest.suite(
        "tokenizer_tests",
        tokenize_test,
    )
