#!/usr/bin/env python3

import argparse
import collections
import json


MNEMONICS = {"SwiftCompile", "SwiftDeriveFiles", "SwiftDumpAST"}
FLAGS = {"-DRSPM_TARGET_COPTS_FIRST", "-DRSPM_TARGET_COPTS_SECOND"}


def load_actions(path):
    with open(path, encoding="utf-8") as file:
        graph = json.load(file)
    return [
        action
        for action in graph.get("actions", [])
        if action.get("mnemonic") in MNEMONICS
    ]


def counts_by_mnemonic(actions):
    return collections.Counter(action["mnemonic"] for action in actions)


def action_arguments(action):
    return set(action.get("arguments", []))


def require_actions(name, actions):
    if not actions:
        raise AssertionError(f"{name}: found no relevant Swift frontend actions")


def require_flags_on_every_action(name, actions):
    for action in actions:
        missing = FLAGS - action_arguments(action)
        if missing:
            raise AssertionError(
                f"{name}: {action['mnemonic']} is missing flags {sorted(missing)}"
            )


def require_no_flags(name, actions):
    for action in actions:
        unexpected = FLAGS & action_arguments(action)
        if unexpected:
            raise AssertionError(
                f"{name}: {action['mnemonic']} unexpectedly has flags {sorted(unexpected)}"
            )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selected-disabled", required=True)
    parser.add_argument("--selected-enabled", required=True)
    parser.add_argument("--sibling-disabled", required=True)
    parser.add_argument("--sibling-enabled", required=True)
    args = parser.parse_args()

    selected_disabled = load_actions(args.selected_disabled)
    selected_enabled = load_actions(args.selected_enabled)
    sibling_disabled = load_actions(args.sibling_disabled)
    sibling_enabled = load_actions(args.sibling_enabled)

    for name, actions in (
        ("selected-disabled", selected_disabled),
        ("selected-enabled", selected_enabled),
        ("sibling-disabled", sibling_disabled),
        ("sibling-enabled", sibling_enabled),
    ):
        require_actions(name, actions)

    if counts_by_mnemonic(selected_disabled) != counts_by_mnemonic(selected_enabled):
        raise AssertionError("selected action counts changed between condition arms")
    if counts_by_mnemonic(sibling_disabled) != counts_by_mnemonic(sibling_enabled):
        raise AssertionError("sibling action counts changed between condition arms")
    if counts_by_mnemonic(selected_disabled) != counts_by_mnemonic(sibling_disabled):
        raise AssertionError("selected and sibling targets expose different frontend action sets")

    require_no_flags("selected-disabled", selected_disabled)
    require_flags_on_every_action("selected-enabled", selected_enabled)
    require_no_flags("sibling-disabled", sibling_disabled)
    require_no_flags("sibling-enabled", sibling_enabled)


if __name__ == "__main__":
    main()
