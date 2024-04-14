package swift

import "encoding/json"

type DepsInfo struct {
	DirectDepRepoNames []string `json:"direct_dep_repo_names"`
}

func NewDepsInfoFromJSON(data []byte) (*DepsInfo, error) {
	var di DepsInfo
	if err := json.Unmarshal(data, &di); err != nil {
		return nil, err
	}
	return &di, nil
}
