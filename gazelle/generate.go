package gazelle

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
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

	allFiles := append(args.RegularFiles, args.GenFiles...)

	// var rules []*rule.Rule
	// var imports
	// for _, f := range allFiles {
	// 	if !isSwiftSourceFile(f) {
	// 		continue
	// 	}
	// }

	return language.GenerateResult{}
}
