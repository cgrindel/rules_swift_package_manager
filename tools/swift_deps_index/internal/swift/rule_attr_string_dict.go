package swift

import (
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/bazelbuild/buildtools/build"
)

func attrStringDict(r *rule.Rule, key string) (map[string]string, error) {
	result := make(map[string]string)
	expr := r.Attr(key)
	if expr == nil {
		return nil, nil
	}

	dictExpr, ok := expr.(*build.DictExpr)
	if !ok {
		return nil, fmt.Errorf("expected %s to be a DictExpr but was %T", key, expr)
	}
	for _, kvExpr := range dictExpr.List {
		dKey, err := stringFromExpr(kvExpr.Key)
		if err != nil {
			return nil, err
		}
		dVal, err := stringFromExpr(kvExpr.Value)
		if err != nil {
			return nil, err
		}
		result[dKey] = dVal
	}

	return result, nil
}

func stringFromExpr(expr build.Expr) (string, error) {
	strExpr, ok := expr.(*build.StringExpr)
	if !ok {
		return "", fmt.Errorf("expected expression to be a string but was %T", expr)
	}
	return strExpr.Value, nil
}
