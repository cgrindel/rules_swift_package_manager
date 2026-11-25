import Foundation

/// Runs SwiftPM for one slice and writes its `swift_deps_cache` and `inc.MODULE.bazel`.
public struct CacheStep {
  private static let mainIdentity = "_main"

  private let inv: Invocation
  private let fileManager = FileManager.default

  public init(_ inv: Invocation) {
    self.inv = inv
  }

  public func run() throws {
    do {
      try runSteps()
    } catch var error as ToolError {
      error.slice = inv.sliceDir
      throw error
    } catch {
      throw ToolError(slice: inv.sliceDir, message: "\(error)")
    }
  }

  private var sliceURL: URL { inv.workspace.appendingPathComponent(inv.sliceDir) }
  private var cacheDir: URL { sliceURL.appendingPathComponent("swift_deps_cache") }
  private var buildDir: URL { sliceURL.appendingPathComponent(".build") }
  private var packageSwift: URL { inv.workspace.appendingPathComponent(inv.packagePath) }
  private var packageDir: URL { packageSwift.deletingLastPathComponent() }
  private var sliceResolved: URL { sliceURL.appendingPathComponent("Package.resolved") }

  private func runSteps() throws {
    try checkSliceDir()
    try checkBazelignore()
    let flags = try SwiftPMFlags(keyValues: inv.flags, workspace: inv.workspace)
    let spm = SwiftPM(
      tool: inv.swiftTool, flags: flags, sliceDir: sliceURL, runfilesDir: inv.runfilesDir)
    let placement = ResolvedPlacement(packageDir: packageDir, sliceDir: sliceURL)
    let patches = inv.patches.mapValues { paths in
      paths.map { inv.workspace.appendingPathComponent($0) }
    }

    let hadSliceResolved = fileManager.fileExists(atPath: sliceResolved.path)
    let (remotes, locals) = try placement.withResolvedInPlace {
      () -> ([String], [(identity: String, packageSwift: URL)]) in
      switch inv.command {
      case .resolve: try spm.run(["resolve"], in: packageDir)
      case .update: try spm.run(["update"], in: packageDir)
      // Fetch any missing checkouts, failing rather than changing a pin.
      case .cache: try runCache(spm: spm, hadSliceResolved: hadSliceResolved)
      }
      let rootDesc = try Manifests.write(
        package: packageDir, cacheDir: cacheDir.appendingPathComponent(Self.mainIdentity),
        workspace: inv.workspace, spm: spm, scratchPath: nil)
      let remotes = try writeRemotes(spm: spm, patches: patches)
      let locals = try writeLocals(spm: spm, rootDesc: rootDesc, remotes: Set(remotes))
      return (remotes, locals)
    }

    try StalenessInputs.write(
      cacheDir: cacheDir, packageSwift: packageSwift, sliceResolved: sliceResolved,
      locals: locals, flags: flags, registries: flags.registries,
      patches: patches, swiftVersion: try spm.version())
    let identities = [Self.mainIdentity] + remotes + locals.map(\.identity)
    _ = try Prune.removeVanished(cacheDir: cacheDir, keep: Set(identities))
    let incModule = sliceURL.appendingPathComponent("inc.MODULE.bazel")
    let text = IncModuleRenderer.render(
      labels: IncModuleFile.labels(
        at: incModule, config: inv.config, swiftLabel: inv.swiftLabel,
        slicePackage: inv.slicePackage),
      identities: identities)
    try Data(text.utf8).write(to: incModule, options: .atomic)
  }

  /// `cache` never picks pins, so a slice without its own `Package.resolved` needs a `resolve`
  /// first. Says so when SwiftPM fails, rather than only passing on SwiftPM's error.
  private func runCache(spm: SwiftPM, hadSliceResolved: Bool) throws {
    do {
      try spm.run(["resolve", "--force-resolved-versions"], in: packageDir)
    } catch var error as ToolError where !hadSliceResolved {
      error.message =
        "no `Package.resolved` in slice `\(inv.sliceDir)`; run "
        + "`bazel run @swift_package//:resolve` under flags that select this slice first "
        + "(\(error.message))"
      throw error
    }
  }

  /// The slice's `Package.resolved` must not be the one SwiftPM writes beside `Package.swift`.
  private func checkSliceDir() throws {
    guard sliceURL.standardizedFileURL.path != packageDir.standardizedFileURL.path else {
      throw ToolError(
        message: "the slice directory must differ from the directory of \(inv.packagePath); "
          + "its Package.resolved would be the one SwiftPM writes beside Package.swift")
    }
  }

  /// Checkouts under `.build` often ship `BUILD.bazel` files; unignored, they become packages.
  private func checkBazelignore() throws {
    let bazelignore = inv.workspace.appendingPathComponent(".bazelignore")
    let entry = "\(inv.sliceDir)/.build"
    let lines = ((try? String(contentsOf: bazelignore, encoding: .utf8)) ?? "")
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    guard lines.contains(entry) else {
      throw ToolError(
        message: "\(bazelignore.path) must list \(entry); run "
          + "`bazel run @rules_swift_package_manager//tools:init` for this slice or add the line")
    }
  }

  /// Dumps a patched copy of each pinned checkout. Returns the identities, in pin order.
  private func writeRemotes(spm: SwiftPM, patches: [String: [URL]]) throws -> [String] {
    let pins =
      fileManager.fileExists(atPath: packageDir.appendingPathComponent("Package.resolved").path)
      ? try Checkouts.pins(resolved: packageDir.appendingPathComponent("Package.resolved")) : []
    if let unknown = Set(patches.keys).subtracting(pins.map(\.identity)).sorted().first {
      throw ToolError(
        package: unknown, message: "patches are configured for a package that is not pinned")
    }
    let checkoutsDir = buildDir.appendingPathComponent("checkouts")
    for pin in pins {
      let workDir = try Checkouts.prepare(
        pin: pin, checkout: Checkouts.checkoutDir(for: pin, checkoutsDir: checkoutsDir),
        workDir: buildDir.appendingPathComponent("rspm/\(pin.identity)"),
        patches: patches[pin.identity] ?? [],
        patchArgs: inv.patchArgs[pin.identity] ?? [])
      _ = try Manifests.write(
        package: workDir, cacheDir: freshCacheDir(pin.identity), workspace: inv.workspace,
        spm: spm,
        scratchPath: workDir.appendingPathComponent(".build"))
    }
    return pins.map(\.identity)
  }

  /// Dumps each local package once, under SwiftPM's identity for a path: the directory name,
  /// lower-cased (not the package name).
  private func writeLocals(spm: SwiftPM, rootDesc: Desc, remotes: Set<String>) throws
    -> [(identity: String, packageSwift: URL)]
  {
    let root = packageDir.standardizedFileURL
    var seen = remotes.union([Self.mainIdentity])
    var locals: [(identity: String, packageSwift: URL)] = []
    _ = try LocalPackages.discover(root: root) { package in
      if package.path == root.path { return rootDesc }
      let identity = package.lastPathComponent.lowercased()
      guard seen.insert(identity).inserted else {
        throw ToolError(
          package: identity,
          message: "local package \(package.path) has the same identity as another package")
      }
      locals.append((identity, package.appendingPathComponent("Package.swift")))
      return try Manifests.write(
        package: package, cacheDir: freshCacheDir(identity), workspace: inv.workspace,
        spm: spm,
        scratchPath: buildDir.appendingPathComponent("rspm-local/\(identity)"))
    }
    return locals
  }

  /// Removes `swift_deps_cache/<identity>` so nothing from an earlier run survives in it.
  private func freshCacheDir(_ identity: String) throws -> URL {
    let dir = cacheDir.appendingPathComponent(identity)
    if fileManager.fileExists(atPath: dir.path) {
      try fileManager.removeItem(at: dir)
    }
    try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    return dir
  }
}
