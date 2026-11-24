import Foundation

/// Undoes `ResolvedPlacement` when SIGINT or SIGTERM stops the tool mid-run.
///
/// Without it, Ctrl-C during a long `swift package resolve` skips the `defer` blocks, leaving
/// the lock and the `Package.resolved` copy beside `Package.swift`. The handler moves the copy
/// back into the slice, removes the lock and exits with 128 plus the signal number (130 for
/// SIGINT, 143 for SIGTERM).
///
/// The handler only calls `rename`, `unlink`, `rmdir` and `_exit`, which are async-signal-safe,
/// on C strings prepared before it is installed.
public enum InterruptCleanup {
  private struct Paths {
    var packageResolved: UnsafeMutablePointer<CChar>
    var sliceResolved: UnsafeMutablePointer<CChar>
    var lockPID: UnsafeMutablePointer<CChar>
    var lockSlice: UnsafeMutablePointer<CChar>
    var lockDir: UnsafeMutablePointer<CChar>

    var all: [UnsafeMutablePointer<CChar>] {
      [packageResolved, sliceResolved, lockPID, lockSlice, lockDir]
    }
  }

  private static let signals: [Int32] = [SIGINT, SIGTERM]

  nonisolated(unsafe) private static var paths: Paths?

  /// Points the handler at one run's files and installs it for SIGINT and SIGTERM.
  static func install(packageResolved: URL, sliceResolved: URL, lockDir: URL) {
    uninstall()
    paths = Paths(
      packageResolved: strdup(packageResolved.path),
      sliceResolved: strdup(sliceResolved.path),
      lockPID: strdup(lockDir.appendingPathComponent("pid").path),
      lockSlice: strdup(lockDir.appendingPathComponent("slice").path),
      lockDir: strdup(lockDir.path))
    for signo in signals {
      _ = signal(signo, handle)
    }
  }

  /// Restores the default handlers and forgets the run's files.
  static func uninstall() {
    for signo in signals {
      _ = signal(signo, SIG_DFL)
    }
    guard let current = paths else { return }
    paths = nil
    current.all.forEach { free($0) }
  }

  /// Moves the copy back and removes the lock, as the signal handler does, without exiting.
  /// Public so tests can run the handler's work inside a placement.
  public static func cleanUp() {
    guard let current = paths else { return }
    // A missing copy fails with ENOENT, which is fine: there is nothing to move.
    _ = rename(current.packageResolved, current.sliceResolved)
    _ = unlink(current.lockPID)
    _ = unlink(current.lockSlice)
    _ = rmdir(current.lockDir)
  }

  private static let handle: @convention(c) (Int32) -> Void = { signo in
    InterruptCleanup.cleanUp()
    _exit(128 + signo)
  }
}
