import Foundation

/// Reads the labels and attributes an existing `inc.MODULE.bazel` already holds.
///
/// `init` writes the file with the labels as the user typed them. The extension passes canonical
/// labels to the tool, so `cache` keeps the file's labels and uses its arguments only for a slice
/// that has no file yet. Canonical names then never reach the committed file.
///
/// The tool owns only `desc_manifests` and `dump_manifests`. Any other attribute the user added
/// to the `from_package` tag (e.g. `netrc`, `registries`, `make_files_read_only`) is kept with its
/// value text unchanged.
public enum IncModuleFile {
  /// A keyword argument of the `from_package` tag that the tool does not own. `value` is the
  /// text after `<name> = ` without the trailing comma; a value that spans lines keeps its
  /// newlines and indentation.
  public struct Attribute: Equatable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
      self.name = name
      self.value = value
    }
  }

  /// The labels to render into a slice's `inc.MODULE.bazel`.
  public struct Labels: Equatable {
    public let config: String
    public let swift: String
    public let resolved: String
    public let slicePackage: String
    /// The user's other attributes, in file order.
    public let extraAttributes: [Attribute]

    public init(
      config: String, swift: String, resolved: String, slicePackage: String,
      extraAttributes: [Attribute] = []
    ) {
      self.config = config
      self.swift = swift
      self.resolved = resolved
      self.slicePackage = slicePackage
      self.extraAttributes = extraAttributes
    }
  }

  /// The attributes the tool writes itself.
  public static let ownedAttributes: Set<String> = [
    "config", "desc_manifests", "dump_manifests", "resolved", "swift",
  ]

  private static let callStart = "swift_deps.from_package("

  private static let resolvedSuffix = ":Package.resolved"

  /// The `config`, `swift` and `resolved` values in the file at `url`, or `nil` when the file
  /// does not exist or lacks one of them.
  public static func existingValues(at url: URL) -> (
    config: String, swift: String, resolved: String
  )? {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    guard let config = value("config", in: text), let swift = value("swift", in: text),
      let resolved = value("resolved", in: text)
    else { return nil }
    return (config, swift, resolved)
  }

  /// The file's labels when it has them, else the ones built from the tool's arguments. The
  /// slice package comes from `resolved` without its `:Package.resolved` suffix; a file whose
  /// `resolved` lacks that suffix is ignored. The file's other attributes are always kept.
  /// Throws when the file exists but its `from_package` call cannot be parsed, rather than
  /// dropping what it cannot read.
  public static func labels(
    at url: URL, config: String, swiftLabel: String, slicePackage: String
  ) throws -> Labels {
    let extras = try extraAttributes(at: url)
    if let existing = existingValues(at: url), existing.resolved.hasSuffix(resolvedSuffix) {
      return Labels(
        config: existing.config, swift: existing.swift, resolved: existing.resolved,
        slicePackage: String(existing.resolved.dropLast(resolvedSuffix.count)),
        extraAttributes: extras)
    }
    return Labels(
      config: config, swift: swiftLabel, resolved: slicePackage + resolvedSuffix,
      slicePackage: slicePackage, extraAttributes: extras)
  }

  /// The attributes of the file's `from_package` call that the tool does not own, or none when
  /// the file does not exist.
  public static func extraAttributes(at url: URL) throws -> [Attribute] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let text: String
    do {
      text = try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw ToolError(message: "cannot read \(url.path): \(error)")
    }
    return try attributes(in: text, path: url.path).filter {
      !ownedAttributes.contains($0.name)
    }
  }

  /// Every keyword argument of the `swift_deps.from_package(` call in `text`, in order.
  ///
  /// The tool and `init` write the file, so the format is known: the call opens on its own line,
  /// each argument starts a line as `<name> = <value>,`, and a line holding only `)` closes the
  /// call. A value may span lines while it has open brackets (e.g. a `dict`). Blank lines are
  /// skipped. Anything else, such as a comment, is an error naming `path`.
  public static func attributes(in text: String, path: String) throws -> [Attribute] {
    func fail(_ line: Int, _ why: String) -> ToolError {
      ToolError(
        message: "cannot parse \(path) line \(line): \(why); "
          + "write each `from_package` attribute as `<name> = <value>,`")
    }
    let lines = text.components(separatedBy: "\n")
    guard
      let start = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == callStart
      })
    else {
      throw ToolError(message: "cannot parse \(path): no `\(callStart)` line")
    }
    var result: [Attribute] = []
    var seen: Set<String> = []
    var index = start + 1
    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == ")" { return result }
      if trimmed.isEmpty {
        index += 1
        continue
      }
      let lineNumber = index + 1
      guard let eq = trimmed.range(of: " = ") else {
        throw fail(lineNumber, "expected `<name> = <value>,`")
      }
      let name = String(trimmed[..<eq.lowerBound])
      guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        throw fail(lineNumber, "`\(name)` is not an attribute name")
      }
      guard seen.insert(name).inserted else {
        throw fail(lineNumber, "`\(name)` is set twice")
      }
      var value = String(trimmed[eq.upperBound...])
      var depth = try bracketDepth(value, line: lineNumber, fail: fail)
      while depth > 0 {
        index += 1
        guard index < lines.count else {
          throw fail(lineNumber, "`\(name)` has an unclosed bracket")
        }
        value += "\n" + lines[index]
        depth += try bracketDepth(lines[index], line: index + 1, fail: fail)
      }
      guard depth == 0, value.hasSuffix(",") else {
        throw fail(lineNumber, "`\(name)` does not end with `,`")
      }
      result.append(Attribute(name: name, value: String(value.dropLast())))
      index += 1
    }
    throw ToolError(message: "cannot parse \(path): the `\(callStart)` call is not closed")
  }

  /// Open minus closed brackets in `line`, ignoring those inside strings.
  private static func bracketDepth(
    _ line: String, line lineNumber: Int, fail: (Int, String) -> ToolError
  ) throws -> Int {
    var depth = 0
    var inString = false
    var escaped = false
    for char in line {
      if inString {
        if escaped {
          escaped = false
        } else if char == "\\" {
          escaped = true
        } else if char == "\"" {
          inString = false
        }
        continue
      }
      switch char {
      case "\"": inString = true
      case "#": throw fail(lineNumber, "comments are not supported")
      case "(", "[", "{": depth += 1
      case ")", "]", "}": depth -= 1
      default: break
      }
    }
    if inString { throw fail(lineNumber, "unterminated string") }
    return depth
  }

  /// The value of the first `<key> = "<value>",` line in `text`.
  private static func value(_ key: String, in text: String) -> String? {
    let pattern = "^\\s*" + NSRegularExpression.escapedPattern(for: key) + " = \"([^\"]*)\",$"
    guard
      let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
      let match = regex.firstMatch(
        in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
      let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
  }
}
