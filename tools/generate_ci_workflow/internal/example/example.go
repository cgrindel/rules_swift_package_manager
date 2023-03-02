package example

import "encoding/json"

type Example struct {
	Name     string   `json:"name"`
	Oss      []string `json:"oss"`
	Versions []string `json:"versions"`
}

func NewExamplesFromJSON(b []byte) ([]Example, error) {
	var examples []Example
	if err := json.Unmarshal(b, &examples); err != nil {
		return nil, err
	}
	return examples, nil
}
