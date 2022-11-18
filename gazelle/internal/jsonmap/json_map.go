package jsonmap

import "log"

func String(jm map[string]any, k string) (string, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return "", false
	}
	switch t := rawValue.(type) {
	case string:
		return rawValue.(string), true
	default:
		log.Println("Expected string for key %v, but was %v", k, t)
		return "", false
	}
}

func Map(jm map[string]any, k string) (map[string]any, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return nil, false
	}
	switch t := rawValue.(type) {
	case []any:
		return rawValue.(map[string]any), true
	default:
		log.Println("Expected map[string]any for key %v, but was %v", k, t)
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
		log.Println("Expected []any for key %v, but was %v", k, t)
		return nil, false
	}
}
