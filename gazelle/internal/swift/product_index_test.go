package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

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
var productIndex = make(swift.ProductIndex)

func init() {
	productIndex.Add(poultryP, anotherPoultryP)
}

func TestProductIndex(t *testing.T) {
	actual := productIndex.Resolve("farm", "Poultry")
	assert.Equal(t, poultryP, actual)

	// Chicken is not a product
	actual = productIndex.Resolve("farm", "Chicken")
	assert.Nil(t, actual)

	// Hen is not a product
	actual = productIndex.Resolve("farm", "Hen")
	assert.Nil(t, actual)

	// Be sure that we disambiguate bewteen the different products named Poultry.
	actual = productIndex.Resolve("zoo", "Poultry")
	assert.Equal(t, anotherPoultryP, actual)
}
