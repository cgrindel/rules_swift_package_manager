package jsonutils_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
	"github.com/stretchr/testify/assert"
)

func TestMissingKeyError(t *testing.T) {
	key := "foo"
	mke := jsonutils.NewMissingKeyError(key)
	assert.Equal(t, key, mke.Key)
	assert.Implements(t, (*error)(nil), mke)
}

func TestKeyTypeError(t *testing.T) {
	key := "foo"
	expectedType := "string"
	kte := jsonutils.NewKeyTypeError(key, expectedType, 123)
	assert.Equal(t, key, kte.Key)
	assert.Equal(t, expectedType, kte.ExpectedType)
	assert.Equal(t, "int", kte.ActualType)
}
