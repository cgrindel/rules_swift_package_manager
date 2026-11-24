import Foundation

/// Puts a slice's `Package.resolved` beside `Package.swift` while SwiftPM runs.
///
/// SwiftPM reads and writes `Package.resolved` next to `Package.swift` and cannot be told to use
/// another path. Each slice keeps its own copy, so a run copies the slice's file in, runs the
/// body, and moves the result back. A `mkdir` lock at `<packageDir>/.rspm_resolve_lock/` keeps
/// runs for different slices from overlapping. It holds `pid` and `slice` files so a later run
/// can report who holds it or clear it after a crash.
public struct ResolvedPlacement {
  private static let resolvedName = "Package.resolved"

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
  public static func processIsAlive(_ pid: Int32) -> Bool {
    kill(pid, 0) == 0 || errno == EPERM
  }

  public func withResolvedInPlace<T>(_ body: () throws -> T) throws -> T {
    try acquireLock(retry: true)
    defer { try? fileManager.removeItem(at: lockDir) }

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
    if fileManager.fileExists(atPath: packageResolved.path) {
      if fileManager.fileExists(atPath: sliceResolved.path) {
        try fileManager.removeItem(at: sliceResolved)
      }
      try fileManager.moveItem(at: packageResolved, to: sliceResolved)
    }
    return try result.get()
  }

  private var packageResolved: URL { packageDir.appendingPathComponent(Self.resolvedName) }
  private var sliceResolved: URL { sliceDir.appendingPathComponent(Self.resolvedName) }
  private var lockDir: URL { packageDir.appendingPathComponent(".rspm_resolve_lock") }
  private var lockPID: URL { lockDir.appendingPathComponent("pid") }
  private var lockSlice: URL { lockDir.appendingPathComponent("slice") }

  private func acquireLock(retry: Bool) throws {
    do {
      try fileManager.createDirectory(at: lockDir, withIntermediateDirectories: false)
    } catch {
      // Any failure other than "the lock already exists" is a real error.
      guard fileManager.fileExists(atPath: lockDir.path) else { throw error }
      guard retry else {
        throw self.error("could not acquire the lock at \(lockDir.path)")
      }
      try clearDeadLock()
      try acquireLock(retry: false)
      return
    }
    do {
      try String(pid).write(to: lockPID, atomically: true, encoding: .utf8)
      try sliceDir.path.write(to: lockSlice, atomically: true, encoding: .utf8)
    } catch {
      try? fileManager.removeItem(at: lockDir)
      throw error
    }
  }

  /// Fails if the lock holder is alive. Otherwise removes its leftover copy and the lock.
  private func clearDeadLock() throws {
    let holderSlice = (try? String(contentsOf: lockSlice, encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let holderPID = readLockPID(), isAlive(holderPID) {
      throw error(
        "another run (pid \(holderPID), slice \(holderSlice ?? "unknown")) holds the lock at "
          + "\(lockDir.path)")
    }
    // The dead run's copy is only safe to delete when its slice still has its own file.
    if let holderSlice, !holderSlice.isEmpty,
      fileManager.fileExists(
        atPath: URL(fileURLWithPath: holderSlice).appendingPathComponent(Self.resolvedName).path),
      fileManager.fileExists(atPath: packageResolved.path)
    {
      try fileManager.removeItem(at: packageResolved)
    }
    try fileManager.removeItem(at: lockDir)
  }

  private func readLockPID() -> Int32? {
    guard let text = try? String(contentsOf: lockPID, encoding: .utf8) else { return nil }
    return Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private func error(_ message: String) -> ToolError {
    ToolError(slice: sliceDir.path, message: message)
  }
}
