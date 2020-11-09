package cmd

import (
	"fmt"
	api "github.com/repustate/cli/api-client/v4"
	"github.com/spf13/cobra"
	"io/ioutil"
	"strings"
)

const (
	textFlag = "text"
	fileFlag = "file"
	langFlag = "lang"
)

var (
	validLangs = []string{
		"en",
		"ar",
		"fr",
		"it",
		"ru",
		"pt",
		"de",
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
				msg := fmt.Sprintf("one of '--text' or '--filename' should be used")
				printErr(msg)
				cmd.Usage()
				return
			}

			if text == "" {
				data, err := ioutil.ReadFile(filename)
				if err != nil {
					msg := fmt.Sprintf("failed read file: %v", err)
					printErr(msg)
					return
				}

				text = string(data)
			}

			if err := doIndex(c, text, lang); err != nil {
				msg := fmt.Sprintf("Failed index document: %v", err)
				printErr(msg)
				return
			} else {
				printMsg("Document successfully indexed")
			}
		},
	}

	cmd.Flags().StringP(textFlag, "t", "", "Text to index")
	cmd.Flags().StringP(fileFlag, "f", "", "File with text content to index")
	cmd.MarkFlagFilename(fileFlag)
	cmd.Flags().StringP(langFlag, "l", "", "Content language")

	return cmd
}

func doIndex(c *api.Client, text, lang string) error {
	user, err := loadUser()
	if err != nil {
		return err
	}

	return c.Index(text, lang, user)
}
