/// Renders a slice's `inc.MODULE.bazel`, formatted as buildifier would.
public enum IncModuleRenderer {
  /// Identities are sorted, so the output only changes when the set of packages does.
  public static func render(
    config: String, swiftLabel: String, resolvedLabel: String, slicePackage: String,
    identities: [String]
  ) -> String {
    let sorted = identities.sorted()
    func manifests(_ attribute: String, _ file: String) -> String {
      guard !sorted.isEmpty else { return "    \(attribute) = {},\n" }
      let entries = sorted.map { id in
        "        \"\(id)\": \"\(slicePackage):swift_deps_cache/\(id)/\(file)\",\n"
      }
      return "    \(attribute) = {\n" + entries.joined() + "    },\n"
    }
    return """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "\(config)",
          swift = "\(swiftLabel)",
          resolved = "\(resolvedLabel)",

      """
        + manifests("dump_manifests", "dump.json")
        + manifests("desc_manifests", "desc.json")
        + ")\n"
  }

  /// Renders with the labels `IncModuleFile.labels` picked.
  public static func render(labels: IncModuleFile.Labels, identities: [String]) -> String {
    render(
      config: labels.config, swiftLabel: labels.swift, resolvedLabel: labels.resolved,
      slicePackage: labels.slicePackage, identities: identities)
  }
}
