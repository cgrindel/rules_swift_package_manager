import AsyncAlgorithms
import Collections
import NIO
let orderedSet = OrderedSet([1, 2, 3, 4, 5])

print("Hello, world!")
print(orderedSet)

// Declared by the patch in third-party/swift-collections.
print(CollectionsPatchMarker.applied)

let buffer = ByteBuffer(string: "10101010101")
print(buffer)

let stream = AsyncStream<Int> { continuation in
    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)
    continuation.finish()
}

for await value in stream {
    print(value)
}
