package swiftpkg

import "github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"

// A Platform represents a Swift package platform.
type Platform struct {
	Name    string
	Version string
}

// NewPlatfromFromManifestInfo returns a Swift package platform from manifest information.
func NewPlatfromFromManifestInfo(descP *spdesc.Platform) *Platform {
	return &Platform{
		Name:    descP.Name,
		Version: descP.Version,
	}
}
