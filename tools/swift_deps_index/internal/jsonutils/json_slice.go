package jsonutils

func valueAtIndex(js []any, idx int) (any, error) {
	jsLen := len(js)
	if idx >= jsLen {
		return nil, NewIndexOutOfBoundsError(idx, jsLen)
	}
	return js[idx], nil
}

// StringAtIndex returns the slice value at the specified index as a string.
func StringAtIndex(js []any, idx int) (string, error) {
	rawValue, err := valueAtIndex(js, idx)
	if err != nil {
		return "", err
	}
	switch t := rawValue.(type) {
	case string:
		return t, nil
	default:
		return "", NewIndexTypeError(idx, "string", t)
	}
}
