package swift

import (
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

type BazelRepo struct {
	Name     string
	Identity string
	PkgInfo  *swiftpkg.PackageInfo
	Pin      *spreso.Pin
}

func NewBazelRepo(
	identity string,
	pkgInfo *swiftpkg.PackageInfo,
	pin *spreso.Pin,
) (*BazelRepo, error) {
	return &BazelRepo{
		Name:     RepoNameFromIdentity(identity),
		Identity: identity,
		PkgInfo:  pkgInfo,
		Pin:      pin,
	}, nil
}
