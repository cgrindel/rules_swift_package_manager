package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	// DEBUG BEGIN
	log.Printf("*** CHUCK: GenerateRules args: %+#v", args)
	// DEBUG END

	// r := rule.NewRule("filegroup", "all_files")
	// srcs := make([]string, 0, len(args.Subdirs)+len(args.RegularFiles))
	// srcs = append(srcs, args.RegularFiles...)
	// for _, f := range args.Subdirs {
	// 	pkg := path.Join(args.Rel, f)
	// 	srcs = append(srcs, "//"+pkg+":all_files")
	// }
	// r.SetAttr("srcs", srcs)
	// r.SetAttr("testonly", true)
	// if args.File == nil || !args.File.HasDefaultVisibility() {
	// 	r.SetAttr("visibility", []string{"//visibility:public"})
	// }
	// return language.GenerateResult{
	// 	Gen:     []*rule.Rule{r},
	// 	Imports: []interface{}{nil},
	// }

	// allFiles := append(args.RegularFiles, args.GenFiles...)

	// var rules []*rule.Rule
	// var imports
	// for _, f := range allFiles {
	// 	if !isSwiftSourceFile(f) {
	// 		continue
	// 	}
	// }

	result := language.GenerateResult{}

	if isModuleRootDir(args.Rel) == noResult {
		// DEBUG BEGIN
		log.Printf("*** CHUCK: IS_NOT_MODULE args.Dir: %+#v", args.Dir)
		// DEBUG END
		return result
	}
	// DEBUG BEGIN
	log.Printf("*** CHUCK: IS_MODULE args.Dir: %+#v", args.Dir)
	// DEBUG END

	return result
}

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

type yesNoMaybe int

const (
	// The
	noResult yesNoMaybe = iota
	yesResult
	maybeResult
)

func isModuleRootDir(path string) yesNoMaybe {
	// If we do not see the module parent in the path, we could be a Swift module
	moduleParentDistance := distanceFromPath(moduleParentDirNames, path, 0)
	switch moduleParentDistance {
	case -1:
		return maybeResult
	case 1:
		return yesResult
	default:
		return noResult
	}
}

func distanceFromPath(values []string, path string, distance int) int {
	if path == "" {
		return -1
	}
	basename := filepath.Base(path)
	if slices.Contains(values, basename) {
		return distance
	}
	dir := filepath.Dir(path)
	return distanceFromPath(values, dir, distance+1)
}
