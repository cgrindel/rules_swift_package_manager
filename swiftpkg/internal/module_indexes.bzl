"""Module for resolving module names to labels."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

def _new_from_json(json_str):
    orig_dict = json.decode(json_str)
    parsed_dict = {
        mod_name: [
            bazel_labels.parse(lbl_str)
            for lbl_str in lbl_strs
        ]
        for (mod_name, lbl_strs) in orig_dict.items()
    }
    return parsed_dict

module_indexes = struct(
    new_from_json = _new_from_json,
)
