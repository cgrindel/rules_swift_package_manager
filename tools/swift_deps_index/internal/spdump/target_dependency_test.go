package spdump_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
	"github.com/stretchr/testify/assert"
)

func TestTargetDependencyImportName(t *testing.T) {
	t.Run("product", func(t *testing.T) {
		td := spdump.TargetDependency{
			Product: &spdump.ProductReference{
				ProductName:    "ArgumentParser",
				DependencyName: "swift-argument-parser",
			},
		}
		actual := td.ImportName()
		assert.Equal(t, "ArgumentParser", actual)
	})
	t.Run("by name", func(t *testing.T) {
		td := spdump.TargetDependency{
			ByName: &spdump.ByNameReference{Name: "MySwiftPackage"},
		}
		actual := td.ImportName()
		assert.Equal(t, "MySwiftPackage", actual)
	})
}
