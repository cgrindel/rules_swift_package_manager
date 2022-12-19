package swift

import (
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

type BazelRepo struct {
	Name    string
	PkgInfo *swiftpkg.PackageInfo
	Pin     *spreso.Pin
}

func NewBazelRepo(
	dep *swiftpkg.Dependency,
	pkgInfo *swiftpkg.PackageInfo,
	pin *spreso.Pin,
) (*BazelRepo, error) {
	repoName, err := RepoNameFromDep(dep)
	if err != nil {
		return nil, err
	}
	return &BazelRepo{
		Name:    repoName,
		PkgInfo: pkgInfo,
		Pin:     pin,
	}, nil
}
