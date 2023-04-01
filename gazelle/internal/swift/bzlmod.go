package swift

import (
	"fmt"
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

func BzlmodStanzas(di *DependencyIndex) (string, error) {
	var b strings.Builder
	if _, err := fmt.Fprint(&b, bzlmodPrefix); err != nil {
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
    deps_index = "//:swift_deps_index.json",
)
use_repo(
    swift_deps,
`

const bzlmodNameTmpl = "    \"%s\",\n"

const bzlmodSuffix = ")\n"
