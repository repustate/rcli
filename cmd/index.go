package cmd

import (
	"fmt"
	"io/ioutil"
	"strings"

	api "github.com/repustate/cli/api-client/v4"
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
		Short: "Index document for further multilingual semantic searches",
		Long: fmt.Sprintf(`Index document for further multilingual semantic searches.
Usage example:
cli index -t="The weather in London is good" -l=en

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

			err := c.Index(text, lang, userUuid)
			if err != nil {
				msg := fmt.Sprintf("Failed to index document: %v", err)
				printErr(msg)
			} else {
				printMsg("Document successfully indexed")
			}
		},
		Example: "index --text=\"Paris is the capitol of France.\" -l=en\r\nindex --filename=~/myfiles/data.txt",
	}

	cmd.Flags().StringP(textFlag, "t", "", "Text to index")
	cmd.Flags().StringP(fileFlag, "f", "", "File with text content to index")
	cmd.MarkFlagFilename(fileFlag)
	cmd.Flags().StringP(langFlag, "l", "", "Content language (default is English)")

	return cmd
}
