package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoNameFromIdentity(t *testing.T) {
	actual := swift.RepoNameFromIdentity("swift-argument-parser")
	assert.Equal(t, "swiftpkg_swift_argument_parser", actual)
}
