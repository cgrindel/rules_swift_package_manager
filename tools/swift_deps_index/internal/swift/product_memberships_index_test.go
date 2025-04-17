package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	mapset "github.com/deckarep/golang-set/v2"
	"github.com/stretchr/testify/assert"
)

func TestProductMembershipsIndex(t *testing.T) {
	awesomeRepoId := "awesome-repo"
	fooPrdName := "Foo"
	barPrdName := "Bar"
	fooM := swift.NewModuleFromLabelStruct(
		"Foo",
		"Foo99",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_Foo"),
		awesomeRepoId,
		[]string{fooPrdName},
	)
	barM := swift.NewModuleFromLabelStruct(
		"Bar",
		"Bar",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_Bar"),
		awesomeRepoId,
		[]string{barPrdName},
	)
	bazM := swift.NewModuleFromLabelStruct(
		"Baz",
		"Baz",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_Baz"),
		awesomeRepoId,
		[]string{barPrdName},
	)

	pmi := make(swift.ProductMembershipsIndex)
	pmi.IndexModule(fooM)
	pmi.IndexModule(barM)
	pmi.IndexModule(bazM)

	tests := []struct {
		msg string
		key swift.ProductIndexKey
		exp mapset.Set[string]
	}{
		{
			msg: "Foo product",
			key: swift.NewProductIndexKey(awesomeRepoId, fooPrdName),
			exp: mapset.NewSet[string](fooM.Name, fooM.C99name),
		},
		{
			msg: "Bar product",
			key: swift.NewProductIndexKey(awesomeRepoId, barPrdName),
			exp: mapset.NewSet[string](barM.Name, bazM.Name),
		},
	}
	for _, tt := range tests {
		actual := pmi[tt.key]
		assert.Equal(t, tt.exp, actual, tt.msg)
	}
}
