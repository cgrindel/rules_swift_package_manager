package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

const aModuleName = "AModule"
const bModuleName = "BModule"
const bC99Name = "BModuleC99"

const awesomeRepoIdentity = "awesome-repo"
const coolPrdName = "CoolProduct"
const crazyPrdName = "CrazyProduct"

const anotherRepoIdentity = "another-repo"
const anotherPrdName = "AnotherProduct"

var coolPrd swift.ProductIndexKey
var crazyPrd swift.ProductIndexKey
var anotherPrd swift.ProductIndexKey

func init() {
	coolPrd = swift.NewProductIndexKey(awesomeRepoIdentity, coolPrdName)
	crazyPrd = swift.NewProductIndexKey(awesomeRepoIdentity, crazyPrdName)
	anotherPrd = swift.NewProductIndexKey(anotherRepoIdentity, anotherPrdName)
}

func TestModuleToProductsIndex(t *testing.T) {
	t.Run("add", func(t *testing.T) {
		mpi := make(swift.ModuleToProductsIndex)
		mpi.Add(aModuleName, coolPrd)
		mpi.Add(bModuleName, coolPrd)
		mpi.Add(aModuleName, anotherPrd)

		tests := []struct {
			msg   string
			mname string
			exp   []swift.ProductIndexKey
		}{
			{
				msg:   aModuleName,
				mname: aModuleName,
				exp:   []swift.ProductIndexKey{coolPrd, anotherPrd},
			},
			{
				msg:   bModuleName,
				mname: bModuleName,
				exp:   []swift.ProductIndexKey{coolPrd},
			},
		}
		for _, tt := range tests {
			actual := mpi[tt.mname]
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
	t.Run("index module", func(t *testing.T) {
		mpi := make(swift.ModuleToProductsIndex)
		mpi.IndexModule(
			swift.NewModuleFromLabelStruct(
				aModuleName,
				aModuleName,
				swiftpkg.SwiftSourceType,
				label.New("swiftpkg_awesome_repo", "", "Sources_AModule"),
				awesomeRepoIdentity,
				[]string{coolPrdName, crazyPrdName},
			),
		)
		mpi.IndexModule(
			swift.NewModuleFromLabelStruct(
				bModuleName,
				bC99Name,
				swiftpkg.SwiftSourceType,
				label.New("swiftpkg_another_repo", "", "Sources_BModule"),
				anotherRepoIdentity,
				[]string{anotherPrdName},
			),
		)

		exp := make(swift.ModuleToProductsIndex)
		exp.Add(aModuleName, coolPrd, crazyPrd)
		exp.Add(bModuleName, anotherPrd)
		exp.Add(bC99Name, anotherPrd)
		assert.Equal(t, exp, mpi)
	})
}
