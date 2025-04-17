// Copyright 2019 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import EchoRequest
import EchoResponse
import EchoServiceServer

struct Echo: EchoService_Echo.SimpleServiceProtocol {
  func echo(
    request: EchoService_EchoRequest,
    context: ServerContext
  ) async throws -> EchoService_EchoResponse {
    return EchoService_EchoResponse.with {
      $0.contents = "You sent: \(request.contents)"
    }
  }
}

@main
struct EchoServer {
  static func main() async throws {
    // Create a plaintext server using the SwiftNIO based HTTP/2 transport
    let host = "0.0.0.0"
    let port = 9000
    let server = GRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: host, port: port),
        transportSecurity: .plaintext
      ),
      services: [Echo()]
    )

    // Start serving indefinitely.
    print("Server started, listening on \("0.0.0.0"):\(port)")
    try await server.serve()
  }
}