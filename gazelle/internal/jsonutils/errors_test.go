package jsonutils_test

import (
	"errors"
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

func TestIsMissingKeyError(t *testing.T) {
	t.Run("err is nil", func(t *testing.T) {
		assert.False(t, jsonutils.IsMissingKeyError(nil))
	})
	t.Run("err is not nil, is not MissingKeyError", func(t *testing.T) {
		err := errors.New("my error")
		assert.False(t, jsonutils.IsMissingKeyError(err))
	})
	t.Run("err is not nil, is MissingKeyError", func(t *testing.T) {
		err := jsonutils.NewMissingKeyError("foo")
		assert.True(t, jsonutils.IsMissingKeyError(err))
	})
}

func TestKeyTypeError(t *testing.T) {
	key := "foo"
	expectedType := "string"
	kte := jsonutils.NewKeyTypeError(key, expectedType, 123)
	assert.Equal(t, key, kte.Key)
	assert.Equal(t, expectedType, kte.ExpectedType)
	assert.Equal(t, "int", kte.ActualType)
}
