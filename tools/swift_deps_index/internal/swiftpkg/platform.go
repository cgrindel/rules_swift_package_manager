package swiftpkg

import "github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdesc"

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
