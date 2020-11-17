package query

var (
	// maps all sentiment string options to it's shorten variant
	sentimentLookup = map[string]string{
		"positive": "pos",
		"pos":      "pos",
		"negative": "neg",
		"neg":      "neg",
		"neutral":  "neu",
		"neu":      "neu",
	}

	sentiments = []string{
		"positive",
		"pos",
		"negative",
		"neg",
		"neutral",
		"neu",
	}
)

type sentiment string

func (s sentiment) QueryString() string {
	short := sentimentLookup[string(s)]
	return "sentiment:" + short
}

func HasSentiment(args ...string) bool {
	for _, arg := range args {
		if _, ok := sentimentLookup[arg]; ok {
			return true
		}
	}

	return false
}
