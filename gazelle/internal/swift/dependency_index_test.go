package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

var fooM = swift.NewModule("Foo", label.New("", "Sources/Foo", "Foo"))
var barM = swift.NewModule("Bar", label.New("", "Sources/Bar", "Bar"))
var anotherRepoFooM = swift.NewModule("Foo", label.New("another_repo", "pkg/path", "Foo"))
var poultryP = swift.NewProduct(
	"farm", 
	"Poultry", 
	swift.LibraryProductType, 
	[]label.Label{
		label.New("farm", "poultry", "Chicken"),
		label.New("farm", "poultry", "Hen"),
	},
)
var anotherPoultryP = swift.NewProduct(
	"zoo", 
	"Poultry", 
	swift.LibraryProductType, 
	[]label.Label{
		label.New("zoo", "", "Poultry"),
	},
)
var di = swift.NewDependencyIndex()

func init() {
	di.AddModules(fooM, barM, anotherRepoFooM)
	di.AddProduct(poultryP)
	di.AddProduct(anotherPoultryP)
}

func TestDependencyIndex(t *testing.T) {
	t.Run("resolve module", func(t *testing.T) {
		var actual *swift.Module

		actual = di.ResolveModule("", "DoesNotExist")
		assert.Nil(t, actual)

		actual = di.ResolveModule("", "Bar")
		assert.Equal(t, barM, actual)

		actual = di.ResolveModule("", "Foo")
		assert.Equal(t, fooM, actual)

		actual = di.ResolveModule("another_repo", "Foo")
		assert.Equal(t, anotherRepoFooM, actual)
	})
	t.Run("resolve product", func(t *testing.T) {
		actual := di.ResolveProduct("farm", "Poultry")
		assert.Equal(t, poultryP, actual)

		// Chicken is not a product
		actual = di.ResolveProduct("farm", "Chicken")
		assert.Nil(t, actual)

		// Hen is not a product
		actual = di.ResolveProduct("farm", "Hen")
		assert.Nil(t, actual)

		// Be sure that we disambiguate bewteen the different products named Poultry.
		actual = di.ResolveProduct("zoo", "Poultry")
		assert.Equal(t, anotherPoultryP, actual)
	})
}

func TestJSONRoundtrip(t *testing.T) {
	data, err := di.JSON()
	assert.NoError(t, err)

	newMI, err := swift.NewDependencyIndexFromJSON(data)
	assert.NoError(t, err)
	assert.Equal(t, di, newMI)
}
