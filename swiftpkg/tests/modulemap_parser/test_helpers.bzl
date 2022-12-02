"""Tests for helpers."""

load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//lib:unittest.bzl", "asserts")
load("//swiftpkg/internal/modulemap_parser:errors.bzl", "errors")
load("//swiftpkg/internal/modulemap_parser:parser.bzl", "parser")

def do_parse_test(env, msg, text, expected):
    """Execute a parse test that is expected to succeed.

    Args:
        env: The test env.
        msg: The failure message.
        text: The text to parse.
        expected: The expected value.
    """
    if msg == None:
        fail("A message must be provided.")
    if text == None:
        fail("A text value must be provided.")
    if expected == None:
        fail("An expected value must be provied.")

    actual, err = parser.parse(text)
    asserts.equals(env, None, err, msg)
    asserts.equals(env, expected, actual, msg)

def do_failing_parse_test(env, msg, text, expected_err):
    """Execute a parse test that is expected to fail.

    Args:
        env: The test env.
        msg: The failure message.
        text: The text to parse.
        expected_err: The expected error message.
    """
    if msg == None:
        fail("A message must be provided.")
    if text == None:
        fail("A text value must be provided.")
    if expected_err == None:
        fail("An err must be provied.")

    if types.is_string(expected_err):
        expected_err = errors.new(expected_err)

    actual, err = parser.parse(text)
    asserts.equals(env, expected_err, err, msg)
    asserts.equals(env, None, actual, msg)
