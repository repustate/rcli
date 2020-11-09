package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	api "github.com/repustate/cli/api-client/v4"
)

const (
	queryFlag = "query"
)

// registerCmd represents the search command
func newSearchCmd(c *api.Client) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "search",
		Short: "Finds documents for provided query",
		Long: `Run multilingual semantic search across indexed documents using query provided. 
Usage example:
cli search -q=Location.city

To list all available query terms use help.`,
		Run: func(cmd *cobra.Command, args []string) {
			query := cmd.Flag(queryFlag).Value.String()
			if query == "" {
				printErr("missing query")
				return
			}
			res, err := doSearch(c, query)
			printSearchResult(res, err)
		},
	}

	// add 'list-terms' subcommand
	queryTerms := &cobra.Command{
		Use:   "list-terms",
		Short: "Lists valid search query terms",
		Run: func(cmd *cobra.Command, args []string) {
			for _, term := range queryTerms {
				fmt.Println(term)
			}
		},
	}
	cmd.AddCommand(queryTerms)

	cmd.Flags().StringP(queryFlag, "q", "", "Search query to use")
	cmd.MarkFlagRequired(queryFlag)

	return cmd
}

func doSearch(c *api.Client, query string) (*api.SearchResult, error) {
	user, err := loadUser()
	if err != nil {
		return nil, err
	}

	return c.Search(query, user)
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
