package reslog_test

import (
	"bytes"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/reslog"
	"github.com/stretchr/testify/assert"
)

func TestWriterLogger(t *testing.T) {
	var b bytes.Buffer
	var err error
	wl := reslog.NewLoggerFromWriter(&b)
	err = wl.Log(reslog.NewRuleResolution(rule.NewRule("swift_library", "Foo"), []string{"Bar", "Baz"}))
	assert.NoError(t, err)
	err = wl.Log(reslog.NewRuleResolution(rule.NewRule("swift_library", "Bar"), []string{"Baz"}))
	assert.NoError(t, err)
	err = wl.Flush()
	assert.NoError(t, err)

	actual := b.String()
	assert.Contains(t, actual, "name: Foo")
	assert.Contains(t, actual, "name: Bar")
}

func TestNoopLogger(t *testing.T) {
	var err error
	nl := reslog.NewNoopLogger()
	err = nl.Log(reslog.NewRuleResolution(rule.NewRule("swift_library", "Foo"), []string{"Bar", "Baz"}))
	assert.NoError(t, err)
	err = nl.Log(reslog.NewRuleResolution(rule.NewRule("swift_library", "Bar"), []string{"Baz"}))
	assert.NoError(t, err)
	err = nl.Flush()
	assert.NoError(t, err)
}
