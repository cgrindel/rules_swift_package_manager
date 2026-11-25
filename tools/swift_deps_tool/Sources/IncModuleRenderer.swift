/// Renders a slice's `inc.MODULE.bazel`, formatted as buildifier would.
public enum IncModuleRenderer {
  /// Identities are sorted, so the output only changes when the set of packages does. Keyword
  /// arguments, the user's `extraAttributes` included, are in the alphabetical order that
  /// `bazel mod tidy` rewrites them to. An extra attribute's value text is written unchanged.
  public static func render(
    config: String, swiftLabel: String, resolvedLabel: String, slicePackage: String,
    identities: [String], extraAttributes: [IncModuleFile.Attribute] = []
  ) -> String {
    let sorted = identities.sorted()
    func manifests(_ attribute: String, _ file: String) -> String {
      guard !sorted.isEmpty else { return "    \(attribute) = {},\n" }
      let entries = sorted.map { id in
        "        \"\(id)\": \"\(slicePackage):swift_deps_cache/\(id)/\(file)\",\n"
      }
      return "    \(attribute) = {\n" + entries.joined() + "    },\n"
    }
    var arguments: [(name: String, text: String)] = [
      ("config", "    config = \"\(config)\",\n"),
      ("desc_manifests", manifests("desc_manifests", "desc.json")),
      ("dump_manifests", manifests("dump_manifests", "dump.json")),
      ("resolved", "    resolved = \"\(resolvedLabel)\",\n"),
      ("swift", "    swift = \"\(swiftLabel)\",\n"),
    ]
    arguments += extraAttributes.map { ($0.name, "    \($0.name) = \($0.value),\n") }
    // Names are unique (`IncModuleFile` rejects duplicates), so this order is total.
    arguments.sort { $0.name < $1.name }
    return """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(

      """
      + arguments.map(\.text).joined()
      + ")\n"
  }

  /// Renders with the labels `IncModuleFile.labels` picked.
  public static func render(labels: IncModuleFile.Labels, identities: [String]) -> String {
    render(
      config: labels.config, swiftLabel: labels.swift, resolvedLabel: labels.resolved,
      slicePackage: labels.slicePackage, identities: identities,
      extraAttributes: labels.extraAttributes)
  }
}
