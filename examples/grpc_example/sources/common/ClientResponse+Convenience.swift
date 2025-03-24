// This file is copied from ClientResponse+Convenience.swift in GRPCCore
// TODO: Request that they make this public.

import GRPCCore

extension ClientResponse {
    /// Converts a streaming response into a single response.
    ///
    /// - Parameter response: The streaming response to convert.
    public init(stream response: StreamingClientResponse<Message>) async {
        let accepted: Result<Contents, RPCError>
        switch response.accepted {
        case .success(let contents):
            do {
                let metadata = contents.metadata
                var iterator = contents.bodyParts.makeAsyncIterator()
                
                // Happy path: message, trailing metadata, nil.
                let part1 = try await iterator.next()
                let part2 = try await iterator.next()
                let part3 = try await iterator.next()
                
                switch (part1, part2, part3) {
                case (.some(.message(let message)), .some(.trailingMetadata(let trailingMetadata)), .none):
                    let contents = Contents(
                        metadata: metadata,
                        message: message,
                        trailingMetadata: trailingMetadata
                    )
                    accepted = .success(contents)
                    
                case (.some(.message), .some(.message), _):
                    let error = RPCError(
                        code: .unimplemented,
                        message: """
              Multiple messages received, but only one is expected. The server may have \
              incorrectly implemented the RPC or the client and server may have a different \
              opinion on whether this RPC streams responses.
              """
                    )
                    accepted = .failure(error)
                    
                case (.some(.trailingMetadata), .none, .none):
                    let error = RPCError(
                        code: .unimplemented,
                        message: "No messages received, exactly one was expected."
                    )
                    accepted = .failure(error)
                    
                case (_, _, _):
                    let error = RPCError(
                        code: .internalError,
                        message: """
              The stream from the client transport is invalid. This is likely to be an incorrectly \
              implemented transport. Received parts: \([part1, part2, part3])."
              """
                    )
                    accepted = .failure(error)
                }
            } catch let error as RPCError {
                // Known error type.
                accepted = .success(Contents(metadata: contents.metadata, error: error))
            } catch {
                // Unexpected, but should be handled nonetheless.
                accepted = .failure(RPCError(code: .unknown, message: String(describing: error)))
            }
            
        case .failure(let error):
            accepted = .failure(error)
        }
        
        self.init(accepted: accepted)
    }
}

extension StreamingClientResponse {
    /// Returns a new response which maps the messages of this response.
    ///
    /// - Parameter transform: The function to transform each message with.
    /// - Returns: The new response.
    @inlinable
    func map<Mapped>(
        _ transform: @escaping @Sendable (Message) throws -> Mapped
    ) -> StreamingClientResponse<Mapped> {
        switch self.accepted {
        case .success(let contents):
            return StreamingClientResponse<Mapped>(
                metadata: self.metadata,
                bodyParts: RPCAsyncSequence(
                    wrapping: contents.bodyParts.map {
                        switch $0 {
                        case .message(let message):
                            return .message(try transform(message))
                        case .trailingMetadata(let metadata):
                            return .trailingMetadata(metadata)
                        }
                    }
                )
            )
            
        case .failure(let error):
            return StreamingClientResponse<Mapped>(accepted: .failure(error))
        }
    }
}
