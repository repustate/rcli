package v4

type SearchResult struct {
	Total     int `json:"total"`
	Documents []struct {
		Text     string `json:"text"`
		Entities []struct {
			Title           string   `json:"title"`
			Classifications []string `json:"classifications"`
		} `json:"entities"`
	} `json:"matches"`
}
