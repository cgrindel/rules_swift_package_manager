import Foundation

/// Puts a slice's `Package.resolved` beside `Package.swift` while SwiftPM runs.
///
/// SwiftPM reads and writes `Package.resolved` next to `Package.swift` and cannot be told to use
/// another path. Each slice keeps its own copy, so a run copies the slice's file in, runs the
/// body, and moves the result back. A lock directory at `<packageDir>/.rspm_resolve_lock/` keeps
/// runs for different slices from overlapping. It holds `pid` and `slice` files so a later run
/// can report who holds it or clear it after a crash.
///
/// The lock is built in a private sibling directory and renamed into place, so it is never
/// visible without its contents. Renaming a directory onto an existing non-empty one fails, which
/// is how a held lock shows up.
public struct ResolvedPlacement {
  private static let resolvedName = "Package.resolved"
  private static let lockName = ".rspm_resolve_lock"

  private let packageDir: URL
  private let sliceDir: URL
  private let pid: Int32
  private let isAlive: (Int32) -> Bool
  private let fileManager = FileManager.default

  public init(
    packageDir: URL,
    sliceDir: URL,
    pid: Int32 = ProcessInfo.processInfo.processIdentifier,
    isAlive: @escaping (Int32) -> Bool = ResolvedPlacement.processIsAlive
  ) {
    self.packageDir = packageDir
    self.sliceDir = sliceDir
    self.pid = pid
    self.isAlive = isAlive
  }

  /// Reports whether a process with this PID exists. `EPERM` means it exists but is not ours.
  /// PIDs of 0 and below name process groups, for which `kill` also succeeds, so they are dead.
  public static func processIsAlive(_ pid: Int32) -> Bool {
    pid > 0 && (kill(pid, 0) == 0 || errno == EPERM)
  }

  public func withResolvedInPlace<T>(_ body: () throws -> T) throws -> T {
    try acquireLock(retry: true)
    defer { releaseLock() }

    if fileManager.fileExists(atPath: packageResolved.path) {
      throw error(
        """
        found \(packageResolved.path), a v1 leftover beside Package.swift. \
        Seed a slice from it with `init --seed \(packageResolved.path)`, then delete the file \
        beside Package.swift.
        """)
    }
    if fileManager.fileExists(atPath: sliceResolved.path) {
      try fileManager.copyItem(at: sliceResolved, to: packageResolved)
    }

    let result: Result<T, Error>
    do {
      result = .success(try body())
    } catch {
      result = .failure(error)
    }
    do {
      try moveBack()
    } catch let moveError as ToolError {
      // A move-back failure must not hide the body's error.
      guard case .failure(let bodyError) = result else { throw moveError }
      guard var bodyError = bodyError as? ToolError else { throw bodyError }
      bodyError.message += "; also, \(moveError.message)"
      throw bodyError
    }
    return try result.get()
  }

  private var packageResolved: URL { packageDir.appendingPathComponent(Self.resolvedName) }
  private var sliceResolved: URL { sliceDir.appendingPathComponent(Self.resolvedName) }
  private var lockDir: URL { packageDir.appendingPathComponent(Self.lockName) }

  /// Moves SwiftPM's file into the slice. `rename` replaces the destination atomically.
  private func moveBack() throws {
    guard fileManager.fileExists(atPath: packageResolved.path) else { return }
    guard rename(packageResolved.path, sliceResolved.path) == 0 else {
      let reason = describe(errno: errno)
      throw error("could not move \(packageResolved.path) to \(sliceResolved.path): \(reason)")
    }
  }

  private func acquireLock(retry: Bool) throws {
    let staging = packageDir.appendingPathComponent("\(Self.lockName).\(pid)")
    try? fileManager.removeItem(at: staging)
    do {
      try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
      try String(pid).write(
        to: staging.appendingPathComponent("pid"), atomically: false, encoding: .utf8)
      try sliceDir.path.write(
        to: staging.appendingPathComponent("slice"), atomically: false, encoding: .utf8)
    } catch {
      try? fileManager.removeItem(at: staging)
      throw error
    }
    if rename(staging.path, lockDir.path) == 0 { return }
    let code = errno
    try? fileManager.removeItem(at: staging)
    guard code == EEXIST || code == ENOTEMPTY else {
      throw error("could not create the lock at \(lockDir.path): \(describe(errno: code))")
    }
    guard retry else { throw error("could not acquire the lock at \(lockDir.path)") }
    try stealDeadLock()
    try acquireLock(retry: false)
  }

  /// Fails if the lock holder is alive. Otherwise takes the lock aside under a name unique to this
  /// process, so only one process clears it, then removes it and the dead run's copy.
  private func stealDeadLock() throws {
    let holderPID = readPID(in: lockDir)
    let holderSlice = readSlice(in: lockDir)
    if let holderPID, isAlive(holderPID) {
      throw error(
        "another run (pid \(holderPID), slice \(holderSlice ?? "unknown")) holds the lock at "
          + "\(lockDir.path)")
    }
    let stale = packageDir.appendingPathComponent("\(Self.lockName).stale.\(pid)")
    try? fileManager.removeItem(at: stale)
    // Losing this rename means another process already took the dead lock aside.
    guard rename(lockDir.path, stale.path) == 0 else { return }
    guard readPID(in: stale) == holderPID else {
      // A live run replaced the dead lock between our read and the rename: put it back.
      _ = rename(stale.path, lockDir.path)
      throw error("the lock at \(lockDir.path) changed hands while clearing it; try again")
    }
    // The dead run's copy is only safe to delete when its slice still has its own file.
    if let holderSlice,
      fileManager.fileExists(
        atPath: URL(fileURLWithPath: holderSlice).appendingPathComponent(Self.resolvedName).path),
      fileManager.fileExists(atPath: packageResolved.path)
    {
      try fileManager.removeItem(at: packageResolved)
    }
    try fileManager.removeItem(at: stale)
  }

  /// Removes the lock only if it still names this process.
  private func releaseLock() {
    guard readPID(in: lockDir) == pid else { return }
    try? fileManager.removeItem(at: lockDir)
  }

  private func readPID(in dir: URL) -> Int32? {
    read("pid", in: dir).flatMap { Int32($0) }
  }

  private func readSlice(in dir: URL) -> String? {
    read("slice", in: dir).flatMap { $0.isEmpty ? nil : $0 }
  }

  private func read(_ name: String, in dir: URL) -> String? {
    (try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func describe(errno code: Int32) -> String {
    String(cString: strerror(code))
  }

  private func error(_ message: String) -> ToolError {
    ToolError(slice: sliceDir.path, message: message)
  }
}
