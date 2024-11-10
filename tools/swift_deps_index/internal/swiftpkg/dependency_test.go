package swiftpkg_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestDependencies(t *testing.T) {
	chickenDep := &swiftpkg.Dependency{
		SourceControl: &swiftpkg.SourceControl{
			Identity: "chicken",
		},
	}
	smidgenDep := &swiftpkg.Dependency{
		FileSystem: &swiftpkg.FileSystem{
			Identity: "smidgen",
		},
	}
	deps := swiftpkg.Dependencies{chickenDep, smidgenDep}

	t.Run("identities", func(t *testing.T) {
		actual := deps.Identities()
		expected := []string{"chicken", "smidgen"}
		assert.Equal(t, expected, actual)
	})
}
