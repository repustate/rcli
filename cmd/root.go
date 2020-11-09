package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	client "github.com/repustate/cli/api-client/v4"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "cli",
	Short: "Repustate CLI for semantic search demo",
	Long:  `Command-line interface that allows to try out Repustate semantic search without any registration needed`,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	api, err := client.New()
	if err != nil {
		printErr(err.Error())
		os.Exit(1)
	}

	// install user-defined commands
	for _, c := range []*cobra.Command{
		newRegisterCmd(&api),
		newIndexCmd(&api),
		newSearchCmd(&api),
	} {
		rootCmd.AddCommand(c)
	}

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
