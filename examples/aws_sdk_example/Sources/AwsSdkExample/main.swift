import AWSS3

struct AwsSdkExample {
    static func main() async throws {
        // Simple example that creates an S3 client
        _ = try await S3Client()
        print("AWS SDK Swift S3 client created successfully")
    }
}

try await AwsSdkExample.main()
