package gazelle_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle"
	"github.com/stretchr/testify/assert"
)

const (
	fooModulePath = "path/to/Sources/Foo"
	barModulePath = "path/to/Sources/Bar"
)

func TestModuleFilesCollector(t *testing.T) {
	mfc := gazelle.NewModuleFilesCollector()
	mfc.AppendModuleFiles(fooModulePath, []string{"SubA/Chicken.swift"})
	mfc.AppendModuleFiles(fooModulePath, []string{"SubB/Smidgen.swift"})
	mfc.AppendModuleFiles(barModulePath, []string{"SubC/Hello.swift"})

	actual := mfc.GetModuleFiles(fooModulePath)
	assert.Equal(t, []string{"SubA/Chicken.swift", "SubB/Smidgen.swift"}, actual)

	actual = mfc.GetModuleFiles(barModulePath)
	assert.Equal(t, []string{"SubC/Hello.swift"}, actual)

	actual = mfc.GetModuleFiles("doesNotExist")
	assert.Nil(t, actual)
}
