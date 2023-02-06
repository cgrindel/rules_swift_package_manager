package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestDependencyIndex(t *testing.T) {
	awesomeRepoId := "awesome-repo"
	fooPrdName := "Foo"
	barPrdName := "Bar"
	bazPrdName := "Baz"
	otherPrdName := "Other"
	fooCoreM := swift.NewModuleFromLabelStruct(
		"FooCore",
		"FooCore",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_FooCore"),
		awesomeRepoId,
		[]string{fooPrdName, barPrdName, bazPrdName},
	)
	fooM := swift.NewModuleFromLabelStruct(
		"Foo",
		"Foo",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_Foo"),
		awesomeRepoId,
		[]string{fooPrdName, bazPrdName},
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
		[]string{bazPrdName},
	)
	otherM := swift.NewModuleFromLabelStruct(
		"Other",
		"Other",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_awesome_repo", "", "Sources_Other"),
		awesomeRepoId,
		[]string{otherPrdName},
	)

	// Note that the product is defined to return a single label/module, but provides multiple
	// modules due to the product membership information in the modules.
	// Product: Foo
	// Label: FooM
	// Provided Modules: Foo, FooCore
	fooPrd := swift.NewProduct(
		awesomeRepoId,
		fooPrdName,
		swift.LibraryProductType,
		[]*label.Label{fooM.Label},
	)
	// Product: Bar
	// Label: BarM
	// Provided Modules: Bar, FooCore
	barPrd := swift.NewProduct(
		awesomeRepoId,
		barPrdName,
		swift.LibraryProductType,
		[]*label.Label{barM.Label},
	)
	// Product: Baz
	// Label: BazM
	// Provided Modules: Baz, Foo, FooCore
	bazPrd := swift.NewProduct(
		awesomeRepoId,
		bazPrdName,
		swift.LibraryProductType,
		[]*label.Label{bazM.Label, fooM.Label},
	)
	// Product: Other
	// Label: OtherM
	// Provided Modules: Other
	otherPrd := swift.NewProduct(
		awesomeRepoId,
		otherPrdName,
		swift.LibraryProductType,
		[]*label.Label{otherM.Label},
	)

	// Looks similar to Foo in awesome-repo.
	anotherRepoID := "another-repo"
	anotherFooM := swift.NewModuleFromLabelStruct(
		"Foo",
		"Foo",
		swiftpkg.SwiftSourceType,
		label.New("swiftpkg_ct_another_repo", "", "Sources_Foo"),
		anotherRepoID,
		[]string{fooPrdName},
	)
	anotherFooPrd := swift.NewProduct(
		anotherRepoID,
		fooPrdName,
		swift.LibraryProductType,
		[]*label.Label{anotherFooM.Label},
	)

	directIdentities := []string{awesomeRepoId}

	di := swift.NewDependencyIndex()
	di.AddModule(fooCoreM, fooM, barM, bazM, otherM, anotherFooM)
	// Puprosefully put bazPrd before fooPrd. Need to ensure that overalp affinity is accounted for.
	di.AddProduct(bazPrd, barPrd, otherPrd, fooPrd, anotherFooPrd)

	t.Run("resolve module names to products", func(t *testing.T) {
		tests := []struct {
			msg        string
			mnames     []string
			identities []string
			exp        *swift.ModuleResolutionResult
		}{
			{
				msg:        "no overlap, expect Foo",
				mnames:     []string{"Foo"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{fooPrd},
				},
			},
			{
				msg:        "overlap, expect Foo",
				mnames:     []string{"Foo", "FooCore"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{fooPrd},
				},
			},
			{
				msg:        "no overlap, expect Bar",
				mnames:     []string{"Bar"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{barPrd},
				},
			},
			{
				msg:        "overlap, expect Bar",
				mnames:     []string{"Bar", "FooCore"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{barPrd},
				},
			},
			{
				msg:        "overlap, expect Baz",
				mnames:     []string{"Baz", "FooCore"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{bazPrd},
				},
			},
			{
				msg:        "overlap, expect Foo and Other",
				mnames:     []string{"Foo", "FooCore", "Other"},
				identities: directIdentities,
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{fooPrd, otherPrd},
				},
			},
			{
				msg:        "anther repo, expect Foo",
				mnames:     []string{"Foo"},
				identities: []string{anotherRepoID},
				exp: &swift.ModuleResolutionResult{
					Products: swift.Products{anotherFooPrd},
				},
			},
		}
		for _, tt := range tests {
			actual := di.ResolveModulesToProducts(tt.mnames, tt.identities)
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
	t.Run("find modules", func(t *testing.T) {
		tests := []struct {
			msg        string
			mname      string
			identities []string
			exp        swift.Modules
		}{
			{
				msg:        "lookup by name",
				mname:      "Foo",
				identities: nil,
				exp:        swift.Modules{anotherFooM, fooM},
			},
			{
				msg:        "lookup by name and a single identity",
				mname:      "Foo",
				identities: []string{awesomeRepoId},
				exp:        swift.Modules{fooM},
			},
			{
				msg:        "lookup by name and a multiple identities",
				mname:      "Foo",
				identities: []string{awesomeRepoId, anotherRepoID},
				exp:        swift.Modules{anotherFooM, fooM},
			},
			{
				msg:        "no result",
				mname:      "DoesNotExist",
				identities: nil,
				exp:        nil,
			},
		}
		for _, tt := range tests {
			actual := di.FindModules(tt.mname, tt.identities)
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
	t.Run("JSON roundtrip", func(t *testing.T) {
		data, err := di.JSON()
		assert.NoError(t, err)

		newMI, err := swift.NewDependencyIndexFromJSON(data)
		assert.NoError(t, err)
		assert.Equal(t, di, newMI)
	})
}
