package swift_test

import (
	"encoding/json"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
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
