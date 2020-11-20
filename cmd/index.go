package cmd

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"sort"
	"strings"

	api "github.com/repustate/rcli/api-client/v4"
	"github.com/spf13/cobra"
)

const (
	textFlag = "text"
	fileFlag = "file"
	langFlag = "lang"
)

var (
	validLangs = []string{
		"ar",
		"da",
		"de",
		"en",
		"es",
		"fi",
		"fr",
		"he",
		"id",
		"it",
		"ja",
		"ko",
		"nl",
		"no",
		"pl",
		"pt",
		"ru",
		"sv",
		"th",
		"tr",
		"ur",
		"vi",
		"zh",
	}
)

// registerCmd represents the text index command
func newIndexCmd(c *api.Client) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "index",
		Short: "Add document to a semantic search index",
		Long: fmt.Sprintf(`Add a document to a semantic search index.
Usage example:
rcli index -t="The weather in London is good" -l=en

Valid language codes: %s`, strings.Join(validLangs, ", ")),
		Run: func(cmd *cobra.Command, args []string) {
			text := cmd.Flag(textFlag).Value.String()
			filename := cmd.Flag(fileFlag).Value.String()
			lang := cmd.Flag(langFlag).Value.String()

			if text == "" && filename == "" {
				msg := fmt.Sprintf("one of '--text' or '--filename' is required")
				printErr(msg)
				cmd.Usage()
				return
			}
			if text != "" && filename != "" {
				msg := fmt.Sprintf("only one of '--text' or '--filename' should be used")
				printErr(msg)
				cmd.Usage()
				return
			}

			if text == "" {
				data, err := ioutil.ReadFile(filename)
				if err != nil {
					msg := fmt.Sprintf("failed to read file: %v", err)
					printErr(msg)
					return
				}

				text = string(data)
			}

			res, err := c.Index(text, lang, userUuid)
			printIndexResult(res, err)
		},
		Example: "index --text=\"Paris is the capitol of France.\" -l=en\r\nindex --filename=~/myfiles/data.txt",
	}

	cmd.Flags().StringP(textFlag, "t", "", "Text to index")
	cmd.Flags().StringP(fileFlag, "f", "", "File with text content to index")
	cmd.MarkFlagFilename(fileFlag)
	cmd.Flags().StringP(langFlag, "l", "", "Content language (default is English)")

	return cmd
}

func printIndexResult(res *api.IndexResult, err error) {
	if err != nil {
		msg := fmt.Sprintf("Failed to index document: %v", err)
		printErr(msg)
	} else {
		printMsg("Document successfully indexed.")
		printThemes(res.Themes)
		sentiment := printSentiment(res.Sentiment)
		classes := printClassifications(res.Entities)

		fmt.Println()
		printSearchHints(res.Themes, sentiment, classes)
	}
}

func printThemes(themes []string) {
	if len(themes) == 0 {
		fmt.Println("No themes detected.")
	} else {
		fmt.Println("Themes:")
		for _, theme := range themes {
			fmt.Printf("- %s\n", theme)
		}
	}
}

func printSentiment(sent string) string {
	if sent == "neu" {
		sent = "neutral"
	} else if sent == "pos" {
		sent = "positive"
	} else if sent == "neg" {
		sent = "negative"
	}
	fmt.Printf("Sentiment:\n- %s\n", sent)

	return sent
}

func printClassifications(entities []api.Entity) []string {
	// extract classifications list from detected entities
	classesSet := map[string]bool{}
	var classifications []string
	for _, e := range entities {
		for _, c := range e.Classifications {
			if _, ok := classesSet[c]; !ok {
				classesSet[c] = true
				classifications = append(classifications, c)
			}
		}
	}
	sort.Strings(classifications)

	if len(classifications) == 0 {
		fmt.Println("No classifications found.")
	} else {
		fmt.Println("Classifications:")
		for _, c := range classifications {
			fmt.Printf("- %s\n", c)
		}
	}

	return classifications
}

func printSearchHints(themes []string, sent string, classes []string) {
	var args [][]string
	// search hint for sentiment+theme
	if len(classes) != 0 {
		args = append(args, []string{pickRandElem(classes)})
	}
	// search hint for sentiment+theme
	if len(themes) != 0 {
		args = append(args, []string{sent, pickRandElem(themes)})
	}
	// search hint for sentiment+theme+classification
	if len(themes) != 0 && len(classes) != 0 {
		args = append(args, []string{sent, pickRandElem(themes), pickRandElem(classes)})
	}
	// add sentiment as last-hope search hint
	if len(args) == 0 {
		args = append(args, []string{sent})
	}

	hints := make([]string, len(args))
	for i, arg := range args {
		hints[i] = fmt.Sprintf("`rcli search %s`", strings.Join(arg, " "))
	}
	fmt.Printf("Now try: %s", strings.Join(hints, ", "))
}

func pickRandElem(s []string) string {
	if len(s) == 0 {
		return ""
	}

	randomIndex := rand.Intn(len(s))
	return s[randomIndex]
}
