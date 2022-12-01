package jsonutils

import (
	"encoding/json"
	"math"
)

func StringAtKey(jm map[string]any, k string) (string, error) {
	rawValue, ok := jm[k]
	if !ok {
		return "", NewMissingKeyError(k)
	}
	switch t := rawValue.(type) {
	case string:
		return t, nil
	default:
		return "", NewKeyTypeError(k, "string", t)
	}
}

func IntAtKey(jm map[string]any, k string) (int, error) {
	rawValue, ok := jm[k]
	if !ok {
		return 0, NewMissingKeyError(k)
	}
	switch t := rawValue.(type) {
	case int:
		return t, nil
	case float64:
		// Unmarshal stores all numbers as float64 when unmarshaled to an interface value
		// https://pkg.go.dev/encoding/json#Unmarshal.
		return int(math.Round(t)), nil
	default:
		return 0, NewKeyTypeError(k, "int", t)
	}
}

func MapAtKey(jm map[string]any, k string) (map[string]any, error) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, NewMissingKeyError(k)
	}
	switch t := rawValue.(type) {
	case map[string]any:
		return t, nil
	default:
		return nil, NewKeyTypeError(k, "map[string]any", t)
	}
}

func SliceAtKey(jm map[string]any, k string) ([]any, error) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, NewMissingKeyError(k)
	}
	switch t := rawValue.(type) {
	case []any:
		return t, nil
	default:
		return nil, NewKeyTypeError(k, "[]any", t)
	}
}

func BytesAtKey(jm map[string]any, k string) ([]byte, error) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, NewMissingKeyError(k)
	}
	valueBytes, err := json.Marshal(rawValue)
	if err != nil {
		return nil, NewKeyError(k, err)
	}
	return valueBytes, nil
}

func UnmarshalAtKey(jm map[string]any, k string, v any) error {
	valueBytes, err := BytesAtKey(jm, k)
	if err != nil {
		return err
	}
	if err = json.Unmarshal(valueBytes, v); err != nil {
		return NewKeyError(k, err)
	}
	return nil
}

func StringsAtKey(jm map[string]any, k string) ([]string, error) {
	anyValues, err := SliceAtKey(jm, k)
	if err != nil {
		return nil, err
	}
	values := make([]string, len(anyValues))
	for idx, v := range anyValues {
		switch t := v.(type) {
		case string:
			values[idx] = t
		default:
			return nil, NewKeyError(k, NewIndexTypeError(idx, "string", t))
		}
	}
	return values, nil
}
