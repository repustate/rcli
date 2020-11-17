package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	api "github.com/repustate/rcli/api-client/v4"
)

const (
	listTerms = "list-terms"
	anyValue  = ":*"
)

// registerCmd represents the search command
func newSearchCmd(c *api.Client) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "search",
		Short: "Semantically searches index using the provided query",
		Long: `Run multilingual semantic search across indexed documents using query provided. 

To list all available query terms use '--list-terms'`,
		Run: func(cmd *cobra.Command, args []string) {
			printTerms := cmd.Flag(listTerms).Value.String()
			if printTerms == "true" {
				for _, term := range queryTerms {
					fmt.Println(term)
				}
				return
			}
			if len(args) == 0 {
				printErr("search query is required")
				cmd.Usage()
				return
			}

			term := strings.Join(args, " ")
			res, err := c.Search(term+anyValue, userUuid)

			printSearchResult(res, err)
		},
		ValidArgs: queryTerms,
		Example:   "search Location.city\r\nsearch --list-terms",
	}

	cmd.Flags().Bool(listTerms, false, "Lists available query terms")

	return cmd
}

func printSearchResult(res *api.SearchResult, err error) {
	if err != nil {
		msg := fmt.Sprintf("Search failed: %v", err)
		printErr(msg)
	} else {
		fmt.Printf("Found %d results:\n", res.Total)
		for _, doc := range res.Documents {
			fmt.Printf("---\nText: %q\nEntities:\n", doc.Text)
			for _, entity := range doc.Entities {
				classes := strings.Join(entity.Classifications, ", ")
				fmt.Printf("%q (%s)\n", entity.Title, classes)
			}
		}
	}
}
