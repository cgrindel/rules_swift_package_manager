// This file is copied from ClientRequest+Convenience.swift in GRPCCore
// TODO: Request that they make this public.

import GRPCCore

extension StreamingClientRequest {
  public init(single request: ClientRequest<Message>) {
    self.init(metadata: request.metadata) {
      try await $0.write(request.message)
    }
  }
}
