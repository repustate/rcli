package cmd

import (
	"fmt"
	"strings"

	"github.com/abiosoft/ishell"

	api "github.com/repustate/cli/repustate-client/v4"
)

func NewSearchCmd(c *api.Client) *ishell.Cmd {
	return &ishell.Cmd{
		Name: "search",
		Func: func(ctx *ishell.Context) {
			if len(ctx.Args) == 0 {
				ctx.Println(colorRed("missing query"))
				return
			}
			query := strings.Join(ctx.Args, " ")
			res, err := doSearch(c, query)
			printSearchResult(ctx, res, err)
		},
		Completer: func([]string) []string {
			return queryTerms
		},

		Help: "search documents for provided query",
	}
}

func doSearch(c *api.Client, query string) (*api.SearchResult, error) {
	user, err := loadUser()
	if err != nil {
		return nil, err
	}

	return c.Search(query, "", user)
}

func printSearchResult(ctx *ishell.Context, res *api.SearchResult, err error) {
	if err != nil {
		msg := fmt.Sprintf("Search failed: %v", err)
		ctx.Println(colorRed(msg))
	} else {
		ctx.Printf("Found %d results:\n", res.Total)
		for _, doc := range res.Documents {
			ctx.Printf("---\nText: %q\nEntities:\n", doc.Text)
			for _, entity := range doc.Entities {
				classes := strings.Join(entity.Classifications, ", ")
				ctx.Printf("%q (%s)\n", entity.Title, classes)
			}
		}
	}
}
