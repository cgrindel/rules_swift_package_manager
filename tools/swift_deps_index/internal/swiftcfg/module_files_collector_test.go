package swiftcfg_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftcfg"
	"github.com/stretchr/testify/assert"
)

const (
	fooModulePath = "path/to/Sources/Foo"
	barModulePath = "path/to/Sources/Bar"
)

func TestModuleFilesCollector(t *testing.T) {
	mfc := swiftcfg.NewModuleFilesCollector()
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
