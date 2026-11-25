import Foundation

/// Runs `swift package` through the `swift_toolchain_tool` wrapper with a slice's flags.
public struct SwiftPM {
  /// Defines `BAZEL` while SwiftPM compiles a manifest, so a `Package.swift` can use `#if BAZEL`
  /// for Bazel-only dependencies or settings (#2159).
  ///
  /// The define is always on. It is not part of `SwiftPMFlags`, so it never appears in the
  /// normalized flags and never affects staleness.
  public static let manifestDefine = ["-Xbuild-tools-swiftc", "-DBAZEL"]

  private static let stderrTailLines = 20

  private let tool: URL
  private let flags: SwiftPMFlags
  private let sliceDir: URL
  private let runfilesDir: URL?

  /// `runfilesDir`, when set, is passed to `tool` as `RUNFILES_DIR`.
  public init(tool: URL, flags: SwiftPMFlags, sliceDir: URL, runfilesDir: URL? = nil) {
    self.tool = tool
    self.flags = flags
    self.sliceDir = sliceDir
    self.runfilesDir = runfilesDir
  }

  /// Runs `swift package <manifestDefine> <flags> <args>` in `packageDir` and returns its stdout.
  ///
  /// `scratchPath` replaces the default `<sliceDir>/.build`. If `registries` is configured,
  /// `registries.json` in the config path is linked to it first, as `spl_setup_registries` does.
  ///
  /// `gitCeiling`, when set, becomes `GIT_CEILING_DIRECTORIES`, so that git does not look above
  /// it for a repository. SwiftPM fills a manifest's `Context.gitInformation` from the
  /// repository that contains the package; for a checkout copied without `.git` into the slice,
  /// that would be the user's own repository.
  @discardableResult
  public func run(
    _ args: [String], in packageDir: URL, scratchPath: URL? = nil, gitCeiling: URL? = nil
  ) throws -> Data {
    try linkRegistries()
    let scratch = scratchPath ?? sliceDir.appendingPathComponent(".build")
    var environment: [String: String] = [:]
    if let gitCeiling {
      environment["GIT_CEILING_DIRECTORIES"] = gitCeiling.path
    }
    let result = try launch(
      ["package"] + Self.manifestDefine + flags.arguments(sliceDir: sliceDir, scratchPath: scratch) + args,
      in: packageDir, environment: environment
    )
    guard result.status == 0 else {
      let tail = String(decoding: result.stderr, as: UTF8.self)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .reversed().drop { $0.isEmpty }.reversed()
        .suffix(Self.stderrTailLines)
        .joined(separator: "\n")
      throw ToolError(command: "swift package \(args.joined(separator: " "))", message: tail)
    }
    return result.stdout
  }

  /// Returns the toolchain's Swift version as `major.minor.patch`; a missing patch becomes `0`.
  public func version() throws -> String {
    let result = try launch(["--version"], in: nil)
    let output = String(decoding: result.stdout + result.stderr, as: UTF8.self)
    let regex = try NSRegularExpression(pattern: #"Swift version (\d+)\.(\d+)(?:\.(\d+))?"#)
    let range = NSRange(output.startIndex..., in: output)
    guard result.status == 0, let match = regex.firstMatch(in: output, range: range) else {
      throw ToolError(
        command: "swift --version",
        message: "could not read the Swift version from: \(output)")
    }
    let parts = (1...3).map { index -> String in
      Range(match.range(at: index), in: output).map { String(output[$0]) } ?? "0"
    }
    return parts.joined(separator: ".")
  }

  /// Replaces `<config_path>/registries.json` with a symlink to the configured file.
  private func linkRegistries() throws {
    guard let registries = flags.registries else { return }
    let fileManager = FileManager.default
    let configPath = flags.configPath(sliceDir: sliceDir)
    try fileManager.createDirectory(at: configPath, withIntermediateDirectories: true)
    let link = configPath.appendingPathComponent("registries.json")
    if (try? fileManager.destinationOfSymbolicLink(atPath: link.path)) != nil
      || fileManager.fileExists(atPath: link.path)
    {
      try fileManager.removeItem(at: link)
    }
    try fileManager.createSymbolicLink(at: link, withDestinationURL: registries)
  }

  private func launch(
    _ arguments: [String], in directory: URL?, environment extra: [String: String] = [:]
  ) throws
    -> (status: Int32, stdout: Data, stderr: Data)
  {
    let process = Process()
    process.executableURL = tool
    process.arguments = arguments
    var extra = extra
    if let runfilesDir {
      extra["RUNFILES_DIR"] = runfilesDir.path
    }
    if !extra.isEmpty {
      process.environment = ProcessInfo.processInfo.environment.merging(extra) { $1 }
    }
    if let directory {
      process.currentDirectoryURL = directory
    }
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    do {
      try process.run()
    } catch {
      throw ToolError(
        command: ([tool.path] + arguments).joined(separator: " "),
        message: "failed to launch: \(error)")
    }
    // Drain stderr on another thread so a full pipe cannot block the child.
    var stderr = Data()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
      stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }
    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    group.wait()
    process.waitUntilExit()
    return (process.terminationStatus, stdout, stderr)
  }
}
