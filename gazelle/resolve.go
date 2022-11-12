package gazelle

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/repo"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

func (l *swiftLang) Resolve(
	c *config.Config,
	ix *resolve.RuleIndex,
	rc *repo.RemoteCache,
	r *rule.Rule,
	imports interface{},
	from label.Label) {

	// DEBUG BEGIN
	log.Printf("*** CHUCK: Resolve =========")
	log.Printf("*** CHUCK: Resolve ix: %+#v", ix)
	log.Printf("*** CHUCK: Resolve rc: %+#v", rc)
	log.Printf("*** CHUCK: Resolve r: %+#v", r)
	log.Printf("*** CHUCK: Resolve imports: %+#v", imports)
	log.Printf("*** CHUCK: Resolve from: %+#v", from)
	// DEBUG END

	// TODO(chuck): Add deps attribute here!
}
