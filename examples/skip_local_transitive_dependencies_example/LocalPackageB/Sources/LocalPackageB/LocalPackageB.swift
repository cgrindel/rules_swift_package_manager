import Foundation
import OpenCombine

@MainActor var cancellable: AnyCancellable?

public func doWorkB() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        Task { @MainActor in
            cancellable = Future<Void, Never> { promise in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [promise] in
                    promise(.success(()))
                }
            }
            .sink { _ in
                continuation.resume()
            } receiveValue: { _ in }
        }
    }
}

