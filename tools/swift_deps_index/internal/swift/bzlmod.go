package swift

import (
	"fmt"
	"path/filepath"
	"strings"

	"golang.org/x/exp/slices"
)

func UseRepoNames(di *DependencyIndex) (string, error) {
	directDepPkgs := di.DirectDepPackages()
	directDepNames := make([]string, len(directDepPkgs))
	for idx, pkg := range directDepPkgs {
		directDepNames[idx] = pkg.Name
	}
	slices.Sort(directDepNames)

	var b strings.Builder
	for _, name := range directDepNames {
		if _, err := fmt.Fprintf(&b, bzlmodNameTmpl, name); err != nil {
			return "", err
		}
	}
	return b.String(), nil
}

func BzlmodStanzas(di *DependencyIndex, moduleDir string, diPath string) (string, error) {
	// get the relative path to the package containing the dependency index file
	diDir := filepath.Dir(diPath)
	relPkgPath, err := filepath.Rel(moduleDir, diDir)
	if err != nil {
		return "", err
	}
	if relPkgPath == "." {
		relPkgPath = ""
	}

	// get the index file name and construct the Bazel label for it
	diName := filepath.Base(diPath)
	diLabel := fmt.Sprintf("//%s:%s", relPkgPath, diName)

	// construct the bzlmod stanza prefix
	prefix := fmt.Sprintf(bzlmodPrefix, diLabel)

	var b strings.Builder
	if _, err := fmt.Fprint(&b, prefix); err != nil {
		return "", err
	}
	useRepoNames, err := UseRepoNames(di)
	if err != nil {
		return "", err
	}
	if _, err := fmt.Fprint(&b, useRepoNames); err != nil {
		return "", err
	}
	if _, err := fmt.Fprint(&b, bzlmodSuffix); err != nil {
		return "", err
	}

	return b.String(), nil
}

const bzlmodPrefix = `swift_deps = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "swift_deps",
)
swift_deps.from_file(
    deps_index = "%s",
)
use_repo(
    swift_deps,
`

const bzlmodNameTmpl = "    \"%s\",\n"

const bzlmodSuffix = ")\n"
