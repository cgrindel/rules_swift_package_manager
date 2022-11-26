package swiftcfg_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"github.com/stretchr/testify/assert"
)

func TestSwiftConfigSwiftBin(t *testing.T) {
	sc := swiftcfg.NewSwiftConfig()
	t.Run("no bin path", func(t *testing.T) {
		sc.SwiftBinPath = ""
		actual := sc.SwiftBin()
		assert.Nil(t, actual)
	})
	t.Run("with bin path", func(t *testing.T) {
		sc.SwiftBinPath = "/path/to/swift"
		actual := sc.SwiftBin()
		expected := swiftbin.NewSwiftBin(sc.SwiftBinPath)
		assert.Equal(t, expected, actual)
	})
}

func TestSwiftConfigGenerateRulesMode(t *testing.T) {
	t.Run("no package info", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("has package info, args Dir is not the package dir", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("has package info, args Dir is the package dir", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
}

func TestGetSetSwiftConfig(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}
