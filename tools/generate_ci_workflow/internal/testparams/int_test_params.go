package testparams

import "encoding/json"

const MacOS = "macos"
const LinuxOS = "linux"

type IntTestParams struct {
	Test         string `json:"test"`
	OS           string `json:"os"`
	EnableBzlmod bool   `json:"enable_bzlmod"`
}

func NewIntTestParamsFromJSON(b []byte) ([]IntTestParams, error) {
	var intTestParams []IntTestParams
	if err := json.Unmarshal(b, &intTestParams); err != nil {
		return nil, err
	}
	return intTestParams, nil
}
