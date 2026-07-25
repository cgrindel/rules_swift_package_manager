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
        path_exists_results = {},
        binary_contents = {}):
    def read(path):
        return file_contents.get(path, "")

    def od_stdout(args):
        # Expected command:
        #   od -A n -t x1 -v -j <offset> -N <count> <path>
        # See repository_files.read_bytes for details.
        offset = int(args[7])
        count = int(args[9])
        hex_bytes = binary_contents.get(args[10], [])
        selected = hex_bytes[offset:offset + count]

        # Real od writes a leading space before each byte and wraps long
        # output. Emit the leading space so that the parsing in
        # repository_files.read_bytes is exercised.
        return "".join([" " + hb for hb in selected]) + "\n"

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

        elif args_len == 3 and args[0] == "test" and args[1] == "-e":
            path = args[2]
            return_code = 0 if path_exists_results.get(path, False) else 1
            exec_result = _new_exec_result(return_code = return_code)

        elif args_len >= 4 and args[0] == "find":
            # The find command that we expect is `find -H -L path`.
            # See repository_files.list_files_under for details.
            path = args[3]
            results = find_results.get(path, [])
            exec_result = _new_exec_result(
                stdout = "\n".join(results),
            )
        elif args_len == 11 and args[0] == "od":
            exec_result = _new_exec_result(stdout = od_stdout(args))
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
