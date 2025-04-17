package jsonutils_test

import (
	"fmt"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
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
	assert.Implements(t, (*error)(nil), kte)
}

func TestKeyError(t *testing.T) {
	key := "foo"
	oerr := fmt.Errorf("original error")
	ke := jsonutils.NewKeyError(key, oerr)
	assert.Equal(t, ke.Key, key)
	assert.Equal(t, ke.Err, oerr)
	assert.Implements(t, (*error)(nil), ke)
}

func TestIndexTypeError(t *testing.T) {
	index := 3
	expectedType := "string"
	ite := jsonutils.NewIndexTypeError(index, expectedType, 123)
	assert.Equal(t, index, ite.Index)
	assert.Equal(t, expectedType, ite.ExpectedType)
	assert.Equal(t, "int", ite.ActualType)
	assert.Implements(t, (*error)(nil), ite)
}
