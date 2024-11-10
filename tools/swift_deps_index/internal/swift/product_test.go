package swift_test

import (
	"encoding/json"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	mapset "github.com/deckarep/golang-set/v2"
	"github.com/stretchr/testify/assert"
)

func TestProduct(t *testing.T) {
	t.Run("JSON roundtrip", func(t *testing.T) {
		data, err := json.Marshal(poultryP)
		assert.NoError(t, err)

		var p swift.Product
		err = json.Unmarshal(data, &p)
		assert.NoError(t, err)
		assert.Equal(t, poultryP, &p)
	})
}

func TestProducts(t *testing.T) {
	awesomeRepoId := "awesome-repo"
	fooPrdName := "Foo"
	barPrdName := "Bar"
	fooLabel := label.New("swiftpkg_awesome_repo", "", "Foo")
	barLabel := label.New("swiftpkg_awesome_repo", "", "Bar")
	fooPrd := swift.NewProduct(
		awesomeRepoId,
		fooPrdName,
		swift.LibraryProductType,
		&fooLabel,
	)
	barPrd := swift.NewProduct(
		awesomeRepoId,
		barPrdName,
		swift.LibraryProductType,
		&barLabel,
	)
	products := swift.Products{fooPrd, barPrd}

	t.Run("labels", func(t *testing.T) {
		expected := mapset.NewSet[*label.Label](&fooLabel, &barLabel)
		assert.Equal(t, expected, products.Labels())
	})
}
