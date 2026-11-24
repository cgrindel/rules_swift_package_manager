import Foundation

/// Reads the labels an existing `inc.MODULE.bazel` already holds.
///
/// `init` writes the file with the labels as the user typed them. The extension passes canonical
/// labels to the tool, so `cache` keeps the file's labels and uses its arguments only for a slice
/// that has no file yet. Canonical names then never reach the committed file.
public enum IncModuleFile {
  /// The labels to render into a slice's `inc.MODULE.bazel`.
  public struct Labels: Equatable {
    public let config: String
    public let swift: String
    public let resolved: String
    public let slicePackage: String

    public init(config: String, swift: String, resolved: String, slicePackage: String) {
      self.config = config
      self.swift = swift
      self.resolved = resolved
      self.slicePackage = slicePackage
    }
  }

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
  /// `resolved` lacks that suffix is ignored.
  public static func labels(
    at url: URL, config: String, swiftLabel: String, slicePackage: String
  ) -> Labels {
    if let existing = existingValues(at: url), existing.resolved.hasSuffix(resolvedSuffix) {
      return Labels(
        config: existing.config, swift: existing.swift, resolved: existing.resolved,
        slicePackage: String(existing.resolved.dropLast(resolvedSuffix.count)))
    }
    return Labels(
      config: config, swift: swiftLabel, resolved: slicePackage + resolvedSuffix,
      slicePackage: slicePackage)
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
