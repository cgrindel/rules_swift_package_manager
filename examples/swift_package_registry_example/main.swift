import AsyncAlgorithms
import Collections
import NIO
let orderedSet = OrderedSet([1, 2, 3, 4, 5])

print("Hello, world!")
print(orderedSet)

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
