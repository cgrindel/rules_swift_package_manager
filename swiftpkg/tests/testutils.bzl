"""Implementation for `testutils`."""

def _new_exec_result(return_code = 0, stdout = "", stderr = ""):
    return struct(
        return_code = return_code,
        stdout = stdout,
        stderr = stderr,
    )

def _new_stub_repository_ctx(repo_name, file_contents = {}, find_results = {}):
    def read(path):
        return file_contents.get(path, "")

    # buildifier: disable=unused-variable
    def execute(args, environment = {}, quiet = True):
        # The find command that we expect is `find -H -L path`.
        # See repository_files.list_files_under for details.
        if len(args) >= 4 and args[0] == "find":
            path = args[3]
            results = find_results.get(path, [])
            exec_result = _new_exec_result(
                stdout = "\n".join(results),
            )
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
