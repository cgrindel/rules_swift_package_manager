package example

import "encoding/json"

const MacOS = "macos"
const LinuxOS = "linux"

type Example struct {
	Name     string   `json:"name"`
	OSS      []string `json:"oss"`
	Versions []string `json:"versions"`
}

func NewExamplesFromJSON(b []byte) ([]Example, error) {
	var examples []Example
	if err := json.Unmarshal(b, &examples); err != nil {
		return nil, err
	}
	return examples, nil
}
