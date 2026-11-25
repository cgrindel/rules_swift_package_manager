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

  /// The first line of every file, as `init` and the tool write it.
  public static let useExtensionLine =
    #"swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")"#

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
  /// The tool owns the file and rewrites it, so it accepts only what it can write back: the
  /// `swift_deps = use_extension(...)` line, the call opening on its own line, each argument
  /// starting a line as `<name> = <value>,`, and a line holding only `)` that closes the call. A
  /// value may span lines while it has open brackets (e.g. a `dict`). Blank lines are skipped.
  /// Anything else, such as a comment or another tag, is an error naming `path` and the line,
  /// rather than being dropped on the next rewrite.
  public static func attributes(in text: String, path: String) throws -> [Attribute] {
    func fail(_ line: Int, _ why: String) -> ToolError {
      ToolError(
        message: "cannot parse \(path) line \(line): \(why); "
          + "write each `from_package` attribute as `<name> = <value>,`")
    }
    let lines = text.components(separatedBy: "\n")
    var result: [Attribute]?
    var sawUseExtension = false
    var index = 0
    while index < lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      let lineNumber = index + 1
      if trimmed.isEmpty {
        index += 1
        continue
      }
      if trimmed.hasPrefix("#") { throw commentError(path, lineNumber) }
      if trimmed == useExtensionLine, !sawUseExtension {
        sawUseExtension = true
        index += 1
        continue
      }
      if trimmed == callStart, result == nil {
        let (attributes, end) = try callAttributes(
          lines: lines, start: index, path: path, fail: fail)
        result = attributes
        index = end + 1
        continue
      }
      throw ToolError(
        message: "cannot parse \(path) line \(lineNumber): unexpected content outside the "
          + "`\(callStart)` tag; the tool owns this file and rewrites it, so it holds only the "
          + "`use_extension` line and one `from_package` tag. Put other tags and statements in "
          + "the root MODULE.bazel")
    }
    guard let result else {
      throw ToolError(message: "cannot parse \(path): no `\(callStart)` line")
    }
    return result
  }

  /// The arguments of the call that opens at `lines[start]`, and the index of its `)` line.
  private static func callAttributes(
    lines: [String], start: Int, path: String, fail: (Int, String) -> ToolError
  ) throws -> ([Attribute], Int) {
    var result: [Attribute] = []
    var seen: Set<String> = []
    var index = start + 1
    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == ")" { return (result, index) }
      if trimmed.isEmpty {
        index += 1
        continue
      }
      let lineNumber = index + 1
      if trimmed.hasPrefix("#") { throw commentError(path, lineNumber) }
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
      var depth = try bracketDepth(value, line: lineNumber, path: path, fail: fail)
      while depth > 0 {
        index += 1
        guard index < lines.count else {
          throw fail(lineNumber, "`\(name)` has an unclosed bracket")
        }
        value += "\n" + lines[index]
        depth += try bracketDepth(lines[index], line: index + 1, path: path, fail: fail)
      }
      guard depth == 0, value.hasSuffix(",") else {
        throw fail(lineNumber, "`\(name)` does not end with `,`")
      }
      result.append(Attribute(name: name, value: String(value.dropLast())))
      index += 1
    }
    throw ToolError(message: "cannot parse \(path): the `\(callStart)` call is not closed")
  }

  /// The tool rewrites the file with its arguments sorted, so it has nowhere to keep a comment.
  private static func commentError(_ path: String, _ line: Int) -> ToolError {
    ToolError(
      message: "cannot parse \(path) line \(line): comments are not supported in "
        + "inc.MODULE.bazel; put them in MODULE.bazel")
  }

  /// Open minus closed brackets in `line`, ignoring those inside strings.
  private static func bracketDepth(
    _ line: String, line lineNumber: Int, path: String, fail: (Int, String) -> ToolError
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
      case "#": throw commentError(path, lineNumber)
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
