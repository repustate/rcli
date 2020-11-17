package query

import (
	"fmt"
	"strings"
)

type Term interface {
	QueryString() string
}

func Build(args []string) (string, error) {
	terms := make([]string, len(args))
	for i := range args {
		var t Term
		if HasTheme(args[i]) {
			t = theme(args[i])
		} else if HasSentiment(args[i]) {
			t = sentiment(args[i])
		} else if HasClass(args[i]) {
			t = classification(args[i])
		} else {
			return "", fmt.Errorf("unknown query term: %q", args[i])
		}

		terms[i] = t.QueryString()
	}

	return strings.Join(terms, " AND "), nil
}

func ListTerms(addThemes, addSents, addClasses bool, prefix string) []string {
	var res []string

	if addThemes {
		res = append(res, filter(themes, prefix)...)
	}
	if addSents {
		res = append(res, filter(sentiments, prefix)...)
	}
	if addClasses {
		res = append(res, filter(classes, prefix)...)
	}

	return res
}

func filter(ts []string, prefix string) []string {
	if prefix == "" {
		return ts
	}

	var res []string
	for _, t := range ts {
		if strings.HasPrefix(t, prefix) {
			res = append(res, t)
		}
	}

	return res
}
