package swift

import "github.com/bazelbuild/bazel-gazelle/label"

// LabelStr

type LabelStr string

func NewLabelStr(l *label.Label) LabelStr {
	return LabelStr(l.String())
}

func NewLabel(lblStr LabelStr) (*label.Label, error) {
	str := string(lblStr)
	lbl, err := label.Parse(str)
	if err != nil {
		return nil, err
	}
	return &lbl, nil
}

// LabelStrs

type LabelStrs []LabelStr
