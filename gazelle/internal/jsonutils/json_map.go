package jsonutils

import (
	"encoding/json"
	"log"
)

func String(jm map[string]any, k string) (string, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return "", false
	}
	switch t := rawValue.(type) {
	case string:
		return rawValue.(string), true
	default:
		log.Printf("Expected string for key %v, but was %v", k, t)
		return "", false
	}
}

func Map(jm map[string]any, k string) (map[string]any, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, false
	}
	switch t := rawValue.(type) {
	case map[string]any:
		return rawValue.(map[string]any), true
	default:
		log.Printf("Expected map[string]any for key %v, but was %v", k, t)
		return nil, false
	}
}

func Slice(jm map[string]any, k string) ([]any, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, false
	}
	switch t := rawValue.(type) {
	case []any:
		return rawValue.([]any), true
	default:
		log.Printf("Expected []any for key %v, but was %v", k, t)
		return nil, false
	}
}

func Bytes(jm map[string]any, k string) ([]byte, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, false
	}
	valueBytes, err := json.Marshal(rawValue)
	if err != nil {
		log.Printf("Failed to marshal the value for %v. %v", k, err)
		return nil, false
	}
	return valueBytes, true
}

func Unmarshal(jm map[string]any, k string, v any) bool {
	valueBytes, ok := Bytes(jm, k)
	if !ok {
		return false
	}
	if err := json.Unmarshal(valueBytes, v); err != nil {
		log.Printf("Failed to unmarshal the value bytes for %v. %v", k, err)
		return false
	}
	return true
}

func Strings(jm map[string]any, k string) ([]string, bool) {
	anyValues, ok := Slice(jm, k)
	if !ok {
		return nil, false
	}
	values := make([]string, len(anyValues))
	for idx, v := range anyValues {
		switch t := v.(type) {
		case string:
			values[idx] = v.(string)
		default:
			log.Printf("Expected to string values, but item %v for key %v is a %v", idx, k, t)
			return nil, false
		}
	}
	return values, true
}
