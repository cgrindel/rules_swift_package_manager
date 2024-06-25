package gazelle

import (
	"flag"
	"os"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/reslog"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftbin"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftcfg"
)

// Register Flags

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// Initialize location for custom configuration
	sc := swiftcfg.NewSwiftConfig()

	fs.StringVar(
		&sc.DependencyIndexRel,
		"swift_dependency_index",
		"",
		"the location of the dependency index JSON file",
	)

	switch cmd {
	case "fix", "update":
		fs.StringVar(
			&sc.ResolutionLogPath,
			"resolution_log",
			"",
			"the location of the resolution log file",
		)
	}

	// Store the config for later steps
	swiftcfg.SetSwiftConfig(c, sc)
}

func (sl *swiftLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	var err error
	sc := swiftcfg.GetSwiftConfig(c)

	// GH021: Add flag so that the client can tell us which Swift to use.

	if sc.ResolutionLogPath != "" {
		sc.ResolutionLogFile, err = os.Create(sc.ResolutionLogPath)
		if err != nil {
			return err
		}
		sc.ResolutionLogger = reslog.NewLoggerFromWriter(sc.ResolutionLogFile)
	}

	// Find the Swift executable
	if sc.SwiftBinPath, err = swiftbin.FindSwiftBinPath(); err != nil {
		return err
	}

	// Initialize the module index path. We cannot initialize this path until we get into
	// CheckFlags.
	if sc.DependencyIndexPath == "" && sc.DependencyIndexRel != "" {
		sc.DependencyIndexPath = filepath.Join(c.RepoRoot, sc.DependencyIndexRel)
	}

	// Attempt to load the module index. This is created by update-repos if the client is using
	// external Swift packages (e.g. swift_pacakge).
	if err = sc.LoadDependencyIndex(); err != nil {
		return err
	}
	// Index any of repository rules (e.g. http_archive) that may contain Swift targets.
	for _, r := range c.Repos {
		if err := sc.DependencyIndex.IndexRepoRule(r, c.RepoRoot); err != nil {
			return err
		}
	}

	return nil
}

// Directives

const protoStripImportPrefix = "proto_strip_import_prefix"
const protoImportPrefix = "proto_import_prefix"

const swiftProtoGenerationModeDirective = "swift_proto_generation_mode"
const swiftModuleNamingConventionDirective = "swift_module_naming_convention"
const defaultModuleNameDirective = "swift_default_module_name"
const swiftLibraryTagsDirective = "swift_library_tags"
const swiftGenerateProtoLibrariesDirective = "swift_generate_proto_libraries"
const swiftGenerateGRPCLibrariesWithFlavorsDirective = "swift_generate_grpc_libraries_with_flavors"
const swiftProtoCompilerDirective = "swift_proto_compiler"

func (*swiftLang) KnownDirectives() []string {
	return []string{
		protoStripImportPrefix,
		protoImportPrefix,
		swiftProtoGenerationModeDirective,
		swiftModuleNamingConventionDirective,
		defaultModuleNameDirective,
		swiftLibraryTagsDirective,
		swiftGenerateProtoLibrariesDirective,
		swiftGenerateGRPCLibrariesWithFlavorsDirective,
		swiftProtoCompilerDirective,
	}
}

func (*swiftLang) Configure(c *config.Config, rel string, f *rule.File) {
	if f == nil {
		return
	}

	// Clone the config and set the new value to the clone
	sc := &swiftcfg.SwiftConfig{}
	*sc = *swiftcfg.GetSwiftConfig(c)
	swiftcfg.SetSwiftConfig(c, sc)

	for _, d := range f.Directives {
		switch d.Key {
		case protoStripImportPrefix:
			sc.StripImportPrefix = d.Value
		case protoImportPrefix:
			sc.ImportPrefix = d.Value
		case swiftModuleNamingConventionDirective:
			if d.Value == "" {
				// If unset, leave the default intact.
				break
			}

			sc.ModuleNamingConvention = d.Value
		case swiftProtoGenerationModeDirective:
			if d.Value == "" {
				// If unset, leave the default intact.
				break
			}

			sc.SwiftProtoGenerationMode = d.Value
		case swiftLibraryTagsDirective:
			var tags []string
			if d.Value == "" {
				// Mark swift_library targets as manual.
				// We do this so that they are always built as a dependency of a target
				// which can provide critical configuration information.
				tags = []string{"manual"}
			} else if d.Value == "-" {
				tags = nil
			} else {
				tags = strings.Split(d.Value, ",")
			}
			sc.SwiftLibraryTags = tags
		case swiftGenerateProtoLibrariesDirective:
			if d.Value == "" {
				// If unset, leave the default intact.
				break
			}

			// Otherwise, check if the directive was set to true:
			sc.GenerateSwiftProtoLibraries = d.Value == "true"
		case swiftGenerateGRPCLibrariesWithFlavorsDirective:
			if d.Value == "" {
				// If unset, leave the default intact.
				break
			}

			// Otherwise, parse the flavors:
			var flavors []string
			if d.Value == "-" {
				flavors = nil
			} else {
				flavors = strings.Split(d.Value, ",")
			}
			sc.GenerateSwiftProtoLibraryGRPCFlavors = flavors
		case swiftProtoCompilerDirective:
			if d.Value == "" {
				// If unset, leave the default intact.
				break
			}

			// Otherwise, parse the compilers:
			subcomponents := strings.Split(d.Value, "=")
			flavor := subcomponents[0]
			compiler := subcomponents[1]
			sc.SwiftProtoCompilers[flavor] = compiler
		case defaultModuleNameDirective:
			sc.DefaultModuleNames[rel] = d.Value
		}
	}
}
