package testparams

import "encoding/json"

const MacOS = "macos"
const LinuxOS = "linux"

type IntTestParams struct {
	Test string `json:"test"`
	OS   string `json:"os"`
}

func (itp *IntTestParams) Runner() string {
	switch itp.OS {
	case MacOS:
		return "macos-15"
	case LinuxOS:
		return "ubuntu-22.04"
	default:
		return ""
	}
}

func NewIntTestParamsFromJSON(b []byte) ([]IntTestParams, error) {
	var intTestParams []IntTestParams
	if err := json.Unmarshal(b, &intTestParams); err != nil {
		return nil, err
	}
	return intTestParams, nil
}
