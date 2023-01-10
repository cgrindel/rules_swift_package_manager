package swift_test

import (
	"encoding/json"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

var farmPoultryChickenLabel = label.New("farm", "poultry", "Chicken")
var farmPoultryHenLabel = label.New("farm", "poultry", "Hen")
var zooPoultryLabel = label.New("zoo", "", "Poultry")

var poultryP = swift.NewProduct(
	"farm",
	"Poultry",
	swift.LibraryProductType,
	[]*label.Label{&farmPoultryChickenLabel, &farmPoultryHenLabel},
)
var anotherPoultryP = swift.NewProduct(
	"zoo",
	"Poultry",
	swift.LibraryProductType,
	[]*label.Label{&zooPoultryLabel},
)
var productIndex = make(swift.ProductIndex)

func init() {
	productIndex.Add(poultryP, anotherPoultryP)
}

func TestProductIndex(t *testing.T) {
	t.Run("resolve", func(t *testing.T) {
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
	})
	t.Run("products", func(t *testing.T) {
		actual := productIndex.Products()
		expected := []*swift.Product{poultryP, anotherPoultryP}
		assert.Equal(t, expected, actual)
	})
	t.Run("JSON roundtrip", func(t *testing.T) {
		data, err := json.Marshal(productIndex)
		assert.NoError(t, err)

		var pi swift.ProductIndex
		err = json.Unmarshal(data, &pi)
		assert.NoError(t, err)
		assert.Equal(t, productIndex, pi)
	})
}
