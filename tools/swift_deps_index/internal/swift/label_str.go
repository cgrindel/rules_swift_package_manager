package swift

import "github.com/bazelbuild/bazel-gazelle/label"

// LabelStr

// A LabelStr represents a Bazel label serialized as a string.
type LabelStr string

// NewLabelStr creates a label string.
func NewLabelStr(l *label.Label) LabelStr {
	return LabelStr(l.String())
}

// NewLabel creates a Bazel label from a label string.
func NewLabel(lblStr LabelStr) (*label.Label, error) {
	str := string(lblStr)
	lbl, err := label.Parse(str)
	if err != nil {
		return nil, err
	}
	return &lbl, nil
}

// LabelStrs

// A LabelStrs represents a slice of label strings.
type LabelStrs []LabelStr
