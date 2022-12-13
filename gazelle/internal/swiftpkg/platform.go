package swiftpkg

import "github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"

type Platform struct {
	Name    string
	Version string
}

func NewPlatfromFromManifestInfo(descP *spdesc.Platform) *Platform {
	return &Platform{
		Name:    descP.Name,
		Version: descP.Version,
	}
}
