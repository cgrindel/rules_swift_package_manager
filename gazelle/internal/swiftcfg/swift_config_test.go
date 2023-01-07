package swiftcfg_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
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
		Path: "/path/to/pkg",
		Targets: swiftpkg.Targets{
			&swiftpkg.Target{Name: "Foo", Path: "Sources/Target"},
		},
	}
	sc.PackageInfo = pi

	t.Run("no package info", func(t *testing.T) {
		nopkgSc := swiftcfg.NewSwiftConfig()
		args := language.GenerateArgs{Dir: pi.Path}
		assert.Equal(t, swiftcfg.SrcFileGenRulesMode, nopkgSc.GenerateRulesMode(args))
	})
	t.Run("has package info, args Dir is the package dir", func(t *testing.T) {
		args := language.GenerateArgs{Dir: pi.Path, Rel: ""}
		assert.Equal(t, swiftcfg.SwiftPkgGenRulesMode, sc.GenerateRulesMode(args))
	})
	t.Run("has package info, not package dir, is target dir", func(t *testing.T) {
		args := language.GenerateArgs{Dir: pi.Targets[0].Path, Rel: "Sources/Target"}
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

func TestWriteAndReadDependencyIndex(t *testing.T) {
	// Create temp dir
	dir, err := os.MkdirTemp("", "swiftcfg")
	assert.NoError(t, err)
	defer os.RemoveAll(dir)

	// Create swift config
	origsc := swiftcfg.NewSwiftConfig()
	origsc.DependencyIndexPath = filepath.Join(dir, swiftcfg.DefaultDependencyIndexBasename)

	lbl := label.New("cool_repo", "Sources/Foo", "Foo")
	m := swift.NewModule("Foo", &lbl)
	origsc.DependencyIndex.ModuleIndex.Add(m)

	// Write the index
	err = origsc.WriteDependencyIndex()
	assert.NoError(t, err)

	// Create a new swift config
	newsc := swiftcfg.NewSwiftConfig()
	newsc.DependencyIndexPath = filepath.Join(dir, swiftcfg.DefaultDependencyIndexBasename)

	// Read the index
	err = newsc.LoadDependencyIndex()
	assert.NoError(t, err)

	// Ensure that the indexes are that same
	assert.Equal(t, origsc.DependencyIndex, newsc.DependencyIndex)
}
