package query

var (
	themes = []string{
		"arts",
		"automotive",
		"business",
		"education",
		"energy",
		"entertainment",
		"fashion",
		"finance",
		"food",
		"genders",
		"health",
		"law",
		"media",
		"military",
		"music",
		"politics",
		"religion",
		"science",
		"sex",
		"space",
		"sports",
		"technology",
		"transportation",
		"weather",
	}

	themesLookup = map[string]bool{
		"arts":           true,
		"automotive":     true,
		"business":       true,
		"education":      true,
		"energy":         true,
		"entertainment":  true,
		"fashion":        true,
		"finance":        true,
		"food":           true,
		"genders":        true,
		"health":         true,
		"law":            true,
		"media":          true,
		"military":       true,
		"music":          true,
		"politics":       true,
		"religion":       true,
		"science":        true,
		"sex":            true,
		"space":          true,
		"sports":         true,
		"technology":     true,
		"transportation": true,
		"weather":        true,
	}
)

type theme string

func (t theme) QueryString() string {
	return "theme:" + string(t)
}

func HasTheme(args ...string) bool {
	for _, arg := range args {
		if _, ok := themesLookup[arg]; ok == true {
			return true
		}
	}

	return false
}
