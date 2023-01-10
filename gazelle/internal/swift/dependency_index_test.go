package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

var di = swift.NewDependencyIndex()

func init() {
	di.ModuleIndex.Add(fooM, barM, anotherRepoFooM)
	di.ProductIndex.Add(poultryP, anotherPoultryP)
}

func TestJSONRoundtrip(t *testing.T) {
	data, err := di.JSON()
	assert.NoError(t, err)

	newMI, err := swift.NewDependencyIndexFromJSON(data)
	assert.NoError(t, err)
	assert.Equal(t, di, newMI)
}
