package swiftcfg_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
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
	sc := swiftcfg.NewSwiftConfig()
	pi := &swiftpkg.PackageInfo{
		Dir: "/path/to/pkg",
		DescManifest: &spdesc.Manifest{
			Targets: spdesc.Targets{
				{Name: "Foo", Path: "Sources/Target"},
			},
		},
	}
	sc.PackageInfo = pi

	t.Run("no package info", func(t *testing.T) {
		nopkgSc := swiftcfg.NewSwiftConfig()
		args := language.GenerateArgs{Dir: pi.Dir}
		assert.Equal(t, swiftcfg.SrcFileGenRulesMode, nopkgSc.GenerateRulesMode(args))
	})
	t.Run("has package info, args Dir is the package dir", func(t *testing.T) {
		args := language.GenerateArgs{Dir: pi.Dir, Rel: ""}
		assert.Equal(t, swiftcfg.SwiftPkgGenRulesMode, sc.GenerateRulesMode(args))
	})
	t.Run("has package info, not package dir, is target dir", func(t *testing.T) {
		args := language.GenerateArgs{Dir: pi.DescManifest.Targets[0].Path, Rel: "Sources/Target"}
		assert.Equal(t, swiftcfg.SwiftPkgGenRulesMode, sc.GenerateRulesMode(args))
	})
	t.Run("has package info, not package dir, not target dir", func(t *testing.T) {
		args := language.GenerateArgs{Dir: "/path/to/pkg/other", Rel: "other"}
		assert.Equal(t, swiftcfg.SkipGenRulesMode, sc.GenerateRulesMode(args))
	})
}

func TestGetSetSwiftConfig(t *testing.T) {
	c := config.New()

	actual := swiftcfg.GetSwiftConfig(c)
	assert.Nil(t, actual)

	sc := swiftcfg.NewSwiftConfig()
	swiftcfg.SetSwiftConfig(c, sc)
	actual = swiftcfg.GetSwiftConfig(c)
	assert.Equal(t, sc, actual)
}
