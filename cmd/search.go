package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	api "github.com/repustate/rcli/api-client/v4"
	"github.com/repustate/rcli/cmd/query"
)

const (
	listTerms = "list-terms"
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
				allTerms := query.ListTerms(true, true, true, "")
				for _, term := range allTerms {
					fmt.Println(term)
				}
				return
			}
			if len(args) == 0 {
				printErr("search query is required")
				cmd.Usage()
				return
			}

			if len(args) > 3 {
				msg := fmt.Sprintf("maximum 3 search query terms allowed, got %d", len(args))
				printErr(msg)
				cmd.Usage()
				return
			}

			q, err := query.Build(args)
			if err != nil {
				printErr(err.Error())
				cmd.Usage()
				return
			}
			res, err := c.Search(q, userUuid)

			printSearchResult(res, err)
		},
		ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
			var completions []string

			themes := query.HasTheme(args...)
			sents := query.HasSentiment(args...)
			classes := query.HasClass(args...)

			// every query term type is used,
			// no completion options available
			if classes && sents && themes {
				return completions, cobra.ShellCompDirectiveNoFileComp
			}

			// list terms for given prefix in available term types only
			completions = query.ListTerms(!themes, !sents, !classes, toComplete)
			return completions, cobra.ShellCompDirectiveNoFileComp
		},

		Example: "search Location.city\r\nsearch pos sports Location.city\r\nsearch --list-terms",
	}

	cmd.Flags().Bool(listTerms, false, "Lists available query terms")

	return cmd
}

func printSearchResult(res *api.SearchResult, err error) {
	if err != nil {
		msg := fmt.Sprintf("Search failed: %v", err)
		printErr(msg)
	} else {
		if res.Total == 0 {
			fmt.Println("No documents found.")
			return
		}
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
