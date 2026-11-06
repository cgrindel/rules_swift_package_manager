"""Module for Swift file operations."""

def _has_objc_directive(contents):
    """Determines whether the specified file contains any `@objc` or \
    `@objcMembers` directives indicating that the Swift file will be consumed \
    by Objective-C code.

    Args:
        contents: Swift code as a `string`.

    Returns:
        A `bool` indicating whether the string contains an Objective-C directive.
    """
    result = contents.find("@objc")
    return result >= 0

def _find_import(contents, target_import, start_idx = 0):
    contents_len = len(contents)
    target_stmt = "import {}".format(target_import)
    target_stmt_len = len(target_stmt)

    for _ in range(start_idx, contents_len):
        imp_start_idx = contents.find(target_stmt, start_idx)
        if imp_start_idx < 0:
            return None

        # Include the previous char; looking for word boundary
        frag_start = imp_start_idx
        if frag_start > 0:
            frag_start -= 1

        # Include the next char; looking for word boundary
        imp_end_idx = imp_start_idx + target_stmt_len
        start_idx = imp_end_idx
        frag_end = imp_end_idx + 1
        if frag_end > contents_len:
            # We are at the end of the contents
            frag_end -= 1
        fragment = contents[frag_start:frag_end]
        if fragment.strip() == target_stmt:
            return _new_range(start = imp_start_idx, end = imp_end_idx)

    return None

def _new_range(start, end):
    return struct(
        start = start,
        end = end,
    )

def _look_ahead(contents, idx, value):
    look_head_len = len(value)
    look_ahead_idx = idx + look_head_len
    if look_ahead_idx > len(contents):
        return -1
    look_ahead = contents[idx:look_ahead_idx]
    if look_ahead == value:
        return look_ahead_idx
    return -1

_multiline_str_delim = "\"\"\""

def _collect_string_literal(contents, idx):
    # Check for multiline string (""")
    start_idx = _look_ahead(contents, idx, _multiline_str_delim)
    if start_idx >= 0:
        multiline = True
    else:
        multiline = False
        start_idx = idx + 1

    escape = False
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "\"" and not escape:
            if multiline:
                la_idx = _look_ahead(contents, sidx, _multiline_str_delim)
                if la_idx >= 0:
                    return la_idx
            else:
                return sidx + 1
        elif char == "\\":
            escape = True
        else:
            escape = False

    fail("Did not find the end of the string literal starting at {}.".format(
        idx,
    ))

def _collect_single_line_comment(contents, idx):
    # We know that idx is pointing at //
    start_idx = idx + 2
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "\n":
            return sidx + 1
    fail("Did not find the end of single line comment starting at {}.".format(
        idx,
    ))

def _collect_multiline_comment(contents, idx):
    # We know that idx is pointing at /*
    start_idx = idx + 2
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "*":
            la_idx = _look_ahead(contents, sidx, "*/")
            if la_idx >= 0:
                return la_idx
    fail("Did not find the end of multi-line comment starting at {}.".format(
        idx,
    ))

def _collect_conditional_compilation(contents, idx):
    # Conditional compilation blocks can be nested. We will process until
    # block level is at 0.
    block_level = 1

    # We know that idx is pointing at #if
    start_idx = idx + 3
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "#":
            if _look_ahead(contents, sidx, "#if") >= 0:
                block_level += 1
            else:
                la_idx = _look_ahead(contents, sidx, "#endif")
                if la_idx >= 0:
                    block_level -= 1
                    if block_level == 0:
                        return la_idx

    fail("""\
Did not find the end of the conditional compilation block starting at {}.\
""".format(idx))

def _is_code(contents, target_idx):
    skip_to = -1
    for idx in range(0, len(contents)):
        if skip_to == idx:
            # Need to reset the skip_to before the next check.
            skip_to = -1
        if idx == target_idx:
            # If we are not skipping ahead, then it is a valid code location.
            return skip_to < 0
        if skip_to > idx:
            continue
        elif skip_to >= 0:
            fail("Somehow skip_to is behind. idx: {idx}, skip_to: {skip_to}".format(
                idx = idx,
                skip_to = skip_to,
            ))
        char = contents[idx]
        if char == "\"":
            skip_to = _collect_string_literal(contents, idx)
        elif char == "/":
            if _look_ahead(contents, idx, "//") >= 0:
                skip_to = _collect_single_line_comment(contents, idx)
            elif _look_ahead(contents, idx, "/*") >= 0:
                skip_to = _collect_multiline_comment(contents, idx)
        elif char == "#":
            if _look_ahead(contents, idx, "#if") >= 0:
                skip_to = _collect_conditional_compilation(contents, idx)

    return False

def _has_import(contents, target_import):
    """Determines whether a string contains a Swift import statement for module.

    Args:
        contents: A `string` value to be evaluated.
        target_import: The name of the imported module as a `string`.

    Returns:
        A `bool` indicating whether an import statement for the module was found.
    """
    start_idx = 0
    for _ in range(len(contents)):
        import_range = _find_import(contents, target_import, start_idx = start_idx)
        if import_range == None:
            return False
        if _is_code(contents, import_range.start):
            return True
        start_idx = import_range.end
    return False

_IMPORT_KINDS = ["typealias", "struct", "class", "enum", "protocol", "let", "var", "func"]

def _identifier_char(char):
    return char.isalnum() or char == "_"

def _tokens(contents):
    """Lex source, ignoring comments and literals (including interpolations)."""
    tokens = []
    skip_to = 0
    line = 1
    block_depth = 0
    line_comment = False

    # Each literal/interpolation is [closing delimiter, raw hashes, paren depth].
    # Interpolations are lexed only to find their end; their tokens stay hidden.
    stack = []
    for idx in range(len(contents)):
        char = contents[idx]
        if char == "\n":
            line += 1
            line_comment = False
        if idx < skip_to or line_comment:
            continue
        pair = contents[idx:idx + 2]
        if block_depth:
            if pair == "/*":
                block_depth += 1
                skip_to = idx + 2
            elif pair == "*/":
                block_depth -= 1
                skip_to = idx + 2
            continue
        if stack and stack[-1][0] != ")":
            delimiter, hashes, _ = stack[-1]
            escape = "\\" + hashes
            if contents[idx:idx + len(escape)] == escape:
                next_idx = idx + len(escape)
                if contents[next_idx:next_idx + 1] == "(":
                    stack.append([
                        ")",
                        "",
                        1,
                    ])
                skip_to = next_idx + 1
            elif contents[idx:idx + len(delimiter + hashes)] == delimiter + hashes:
                skip_to = idx + len(delimiter + hashes)
                stack.pop()
            continue
        if pair == "//":
            line_comment = True
            continue
        if pair == "/*":
            block_depth = 1
            skip_to = idx + 2
            continue
        if stack and char in "()":
            stack[-1][2] += 1 if char == "(" else -1
            if stack[-1][2] == 0:
                stack.pop()
            continue
        hashes = ""
        start = idx
        if char == "#":
            for pos in range(idx, len(contents)):
                if contents[pos] != "#":
                    break
                hashes += "#"
            start += len(hashes)
        quote = contents[start:start + 1]

        # Bare slash literals can start after expression-introducing punctuation.
        # Restrict this to avoid consuming division operators as regex literals.
        regex = quote == "/" and (hashes or (tokens and tokens[-1][0] in ["=", "(", "[", ",", ":", "return"]))
        if quote == '"' or regex:
            delimiter = '"""' if contents[start:start + 3] == '"""' else quote
            stack.append([delimiter, hashes, 0])
            skip_to = start + len(delimiter)
            continue
        if stack:
            continue
        if char.isspace():
            continue
        if _identifier_char(char):
            end = idx + 1
            for pos in range(end, len(contents)):
                if not _identifier_char(contents[pos]):
                    break
                end = pos + 1
            tokens.append((contents[idx:end], line))
            skip_to = end
        else:
            tokens.append((char, line))
    return tokens

def _scan_prefix(contents):
    # Native string searches avoid lexing large implementation bodies. Only cut
    # when the last possible import has a complete module name on its own line;
    # unusual/multiline declarations retain the full source. All preceding text
    # remains intact, including comments, directives and literal delimiters.
    last = contents.rfind("import")
    if last < 0:
        return ""
    end = contents.find("\n", last)
    if end < 0:
        return contents
    tail = [piece for piece in contents[last + len("import"):end].strip().replace("\t", " ").split(" ") if piece]
    if tail and tail[0] in _IMPORT_KINDS:
        tail = tail[1:]
    if tail:
        module = tail[0].split(".")[0].removesuffix(";")
        if module.startswith("`") and module.endswith("`"):
            module = module[1:-1]
        if module and not module[0].isdigit() and all([_identifier_char(c) for c in module.elems()]):
            return contents[:end + 1]
    return contents

_OS_PLATFORMS = {"Android": "android", "FreeBSD": "freebsd", "Linux": "linux", "OpenBSD": "openbsd", "WASI": "wasi", "Windows": "windows", "iOS": "ios", "macOS": "macos", "tvOS": "tvos", "visionOS": "visionos", "watchOS": "watchos"}

def _matches(expression, entry, module):
    if expression == None:
        return None
    values = []
    for token in expression:
        if type(token) == "bool":
            values.append(token)
        elif type(token) == "tuple":
            predicate, argument = token
            if predicate == "os" and argument in _OS_PLATFORMS:
                values.append(entry["platform"] == _OS_PLATFORMS[argument])
            elif predicate == "targetEnvironment" and argument == "simulator" and "environment" in entry:
                values.append(entry["environment"] == "simulator")
            elif predicate == "canImport" and argument == module:
                # The inventory entry proves this imported SDK module exists for
                # this exact Xcode and SDK. Unrelated canImport remains unknown.
                values.append(True)
            else:
                return None
        elif token == "!":
            values.append(not values.pop())
        else:
            right = values.pop()
            left = values.pop()
            values.append(left and right if token == "&&" else left or right)
    return values[0]

def _condition(tokens):
    # A deliberately small Boolean grammar. Unknown predicates invalidate the
    # entire expression, including its #else, rather than guessing build flags.
    output = []
    operators = []
    precedence = {"!": 3, "&&": 2, "||": 1}
    expect_operand = True
    skip_to = 0
    for idx, token in enumerate(tokens):
        if idx < skip_to:
            continue
        if expect_operand:
            if token in ["!", "("]:
                operators.append(token)
            elif token in ["true", "false"]:
                output.append(token == "true")
                expect_operand = False
            elif token in ["os", "targetEnvironment", "canImport"] and idx + 3 < len(tokens) and tokens[idx + 1] == "(" and tokens[idx + 3] == ")":
                output.append((token, tokens[idx + 2]))
                skip_to = idx + 4
                expect_operand = False
            else:
                return None
        elif token == ")":
            found = False
            for _ in range(len(operators)):
                op = operators.pop()
                if op == "(":
                    found = True
                    break
                output.append(op)
            if not found:
                return None
        elif token in ["&", "|"] and idx + 1 < len(tokens) and tokens[idx + 1] == token:
            op = token + token
            for _ in range(len(operators)):
                if operators[-1] == "(" or precedence[operators[-1]] < precedence[op]:
                    break
                output.append(operators.pop())
            operators.append(op)
            skip_to = idx + 2
            expect_operand = True
        else:
            return None
    if expect_operand or "(" in operators:
        return None
    output.extend(reversed(operators))
    return output

def _collect_imports(contents):
    """Return Swift imports with nested, conservatively parsed branch conditions.

    Each conditions pair holds a Boolean expression and its required truth value.
    Unsupported expressions are None, including when negated by #else/#elseif.
    """
    tokens = _tokens(_scan_prefix(contents))
    imports = []
    branches = []
    for idx, (token, line) in enumerate(tokens):
        if token == "#" and idx + 1 < len(tokens):
            directive = tokens[idx + 1][0]
            if directive in ["if", "elseif"]:
                expression_tokens = []
                for pos in range(idx + 2, len(tokens)):
                    if tokens[pos][1] != line:
                        break
                    expression_tokens.append(tokens[pos][0])
                expression = _condition(expression_tokens)
                if directive == "if":
                    branches.append({"current": expression, "previous": []})
                elif branches:
                    branches[-1]["previous"].append(branches[-1]["current"])
                    branches[-1]["current"] = expression
            elif directive == "else" and branches:
                branches[-1]["previous"].append(branches[-1]["current"])
                branches[-1]["current"] = [True]
            elif directive == "endif" and branches:
                branches.pop()
        if token != "import" or (idx and tokens[idx - 1][0] in [".", "`"]):
            continue
        next_idx = idx + 1
        if next_idx < len(tokens) and tokens[next_idx][0] in _IMPORT_KINDS:
            next_idx += 1
        if next_idx < len(tokens) and tokens[next_idx][0] == "`":
            next_idx += 1
        if next_idx >= len(tokens):
            continue
        module_name = tokens[next_idx][0]
        if not module_name or not _identifier_char(module_name[0]) or module_name[0].isdigit():
            continue
        conditions = []
        for branch in branches:
            conditions.extend([(expr, False) for expr in branch["previous"]])
            conditions.append((branch["current"], True))
        imports.append(struct(
            module_name = module_name,
            line_number = line,
            is_conditional = bool(branches),
            conditions = conditions,
        ))
    return imports

swift_files = struct(
    matches = _matches,
    collect_imports = _collect_imports,
    scan_prefix = _scan_prefix,
    has_import = _has_import,
    has_objc_directive = _has_objc_directive,
)
