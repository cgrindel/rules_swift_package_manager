"""Implementation for `testutils`."""

def _new_exec_result(return_code = 0, stdout = "", stderr = ""):
    return struct(
        return_code = return_code,
        stdout = stdout,
        stderr = stderr,
    )

def _new_stub_repository_ctx(
        repo_name,
        file_contents = {},
        find_results = {},
        is_directory_results = {},
        file_type_results = {}):
    def read(path):
        return file_contents.get(path, "")

    # buildifier: disable=unused-variable
    def execute(args, environment = {}, quiet = True):
        args_len = len(args)
        if args_len == 3 and args[2].startswith("if [[ -d ") and environment["TARGET_PATH"]:
            # Look for the is_directory check.
            path = environment["TARGET_PATH"]
            result = is_directory_results.get(path, False)
            stdout = "TRUE" if result else "FALSE"
            stdout += "\n"
            exec_result = _new_exec_result(stdout = stdout)

        elif args_len >= 4 and args[0] == "find":
            # The find command that we expect is `find -H -L path`.
            # See repository_files.list_files_under for details.
            path = args[3]
            results = find_results.get(path, [])
            exec_result = _new_exec_result(
                stdout = "\n".join(results),
            )
        elif args_len == 3 and args[0] == "file" and args[1] == "--brief":
            # Expected command: `file --brief path`
            path = args[2]
            results = file_type_results.get(path, "")
            exec_result = _new_exec_result(stdout = results)
        else:
            exec_result = _new_exec_result()
        return exec_result

    return struct(
        name = "bzlmodmangled~" + repo_name,
        read = read,
        execute = execute,
        attr = struct(
            bazel_package_name = repo_name,
        ),
    )

testutils = struct(
    new_stub_repository_ctx = _new_stub_repository_ctx,
)
