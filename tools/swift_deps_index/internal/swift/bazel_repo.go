package swift

import (
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
)

// A BazelRepo represents a Swift package as a Bazel repository for an external dependency.
type BazelRepo struct {
	Name     string
	Identity string
	PkgInfo  *swiftpkg.PackageInfo
	Pin      *spreso.Pin
}

// NewBazelRepo returns a Bazel repo for a Swift package.
func NewBazelRepo(
	identity string,
	pkgInfo *swiftpkg.PackageInfo,
	pin *spreso.Pin,
) *BazelRepo {
	return &BazelRepo{
		Name:     RepoNameFromIdentity(identity),
		Identity: identity,
		PkgInfo:  pkgInfo,
		Pin:      pin,
	}
}
