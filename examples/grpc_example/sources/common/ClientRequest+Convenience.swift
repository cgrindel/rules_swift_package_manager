// This file is copied from ClientRequest+Convenience.swift in GRPCCore
// Requested they make this public: https://github.com/grpc/grpc-swift/issues/2213
// When they do, we can remove this.

import GRPCCore

extension StreamingClientRequest {
  public init(single request: ClientRequest<Message>) {
    self.init(metadata: request.metadata) {
      try await $0.write(request.message)
    }
  }
}
