import LocalLow
import Parsing

// Parse "<user>@<host>" into its two components.
let email = Parse(input: Substring.self) {
    Prefix { $0 != "@" }
    "@"
    Rest()
}

let (user, host) = try email.parse("frodo@shire.example")
print("user=\(user) host=\(host)")
print("LocalLow floor \(LocalLow.floor)")
