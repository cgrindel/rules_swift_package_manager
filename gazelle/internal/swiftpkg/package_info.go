package swiftpkg

type PackageInfo struct {
	// Path to the Package.swift file
	ManifestPath string
	// Path to the Package.resolved file
	ResolvedPath string
}
