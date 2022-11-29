package gazelle_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle"
	"github.com/stretchr/testify/assert"
)

func TestImplementsRepoImporter(t *testing.T) {
	lang := gazelle.NewLanguage()
	assert.Implements(t, (*language.RepoImporter)(nil), lang)
}
