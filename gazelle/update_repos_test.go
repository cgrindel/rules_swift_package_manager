package gazelle_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/rules_swift_package_manager/gazelle"
	"github.com/stretchr/testify/assert"
)

func TestImplementsRepoImporter(t *testing.T) {
	lang := gazelle.NewLanguage()
	assert.Implements(t, (*language.RepoImporter)(nil), lang)
}

func TestCanImport(t *testing.T) {
	lang := gazelle.NewLanguage()
	ri, ok := lang.(language.RepoImporter)
	assert.True(t, ok)

	assert.True(t, ri.CanImport("/path/to/Package.swift"))
	assert.False(t, ri.CanImport("/path/to/Package.resolved"))
	assert.False(t, ri.CanImport("/path/to/some_other_file"))
}
