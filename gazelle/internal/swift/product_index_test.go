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
		tests := []struct {
			identity string
			name     string
			wval     *swift.Product
		}{
			{identity: "farm", name: "Poultry", wval: poultryP},
			{identity: "farm", name: "Chicken", wval: nil},
			{identity: "farm", name: "Hen", wval: nil},
			// Be sure that we disambiguate bewteen the different products named Poultry.
			{identity: "zoo", name: "Poultry", wval: anotherPoultryP},
		}
		for _, tc := range tests {
			actual := productIndex.Resolve(tc.identity, tc.name)
			assert.Equal(t, tc.wval, actual)
		}
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

func TestProductIndexKey(t *testing.T) {
	identity := "awesome-repo"
	name := "Foo"
	pik := swift.NewProductIndexKey(identity, name)
	assert.Equal(t, identity, pik.Identity())
}
