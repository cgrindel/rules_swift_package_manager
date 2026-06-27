import yoga

let config = YGConfigNew()
defer {
    YGConfigFree(config)
}

print("Constructed Yoga config")
