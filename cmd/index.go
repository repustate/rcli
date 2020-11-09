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

func newIndexCmd(c *api.Client) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "index",
		Short: "Index document for further multilingual semantic searches",
		Long: fmt.Sprintf(`Index document for further multilingual semantic searches. Usage example:
index -t="The weather in London is good" -l=en

Valid language codes: %s`, strings.Join(validLangs, ", ")),
		RunE: func(cmd *cobra.Command, args []string) error {
			text := cmd.Flag(textFlag).Value.String()
			filename := cmd.Flag(fileFlag).Value.String()
			lang := cmd.Flag(langFlag).Value.String()

			if text == "" {
				data, err := ioutil.ReadFile(filename)
				if err != nil {
					msg := fmt.Sprintf("failed read file: %v", err)
					fmt.Println(colorRed(msg))
					return err
				}

				text = string(data)
			}

			if err := doIndex(c, text, lang); err != nil {
				msg := fmt.Sprintf("Failed index document: %v", err)
				fmt.Println(colorRed(msg))
				return err
			} else {
				fmt.Println(colorBlue("Document successfully indexed"))
			}

			return nil
		},
	}

	cmd.Flags().StringP(textFlag, "t", "", "Help message for toggle")
	cmd.Flags().StringP(fileFlag, "f", "", "Help message for toggle")
	cmd.MarkFlagFilename(fileFlag)
	cmd.Flags().StringP(langFlag, "l", "", "Help message for toggle")

	return cmd
}

func doIndex(c *api.Client, text, lang string) error {
	user, err := loadUser()
	if err != nil {
		return err
	}

	return c.Index(text, lang, user)
}
