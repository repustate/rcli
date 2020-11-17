package cmd

import (
	"fmt"
	"os"

	"github.com/google/uuid"
	"github.com/spf13/cobra"

	client "github.com/repustate/rcli/api-client/v4"
)

// rootCmd represents the base command when called without any subcommands
var (
	userUuid = ""

	rootCmd = &cobra.Command{
		Use:   "rcli",
		Short: "Repustate CLI for Semantic Search",
		Long:  `Command-line interface to Repustate's Semantic Search engine`,
		// populates user uuid every time executed
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			userUuid = loadUserUUID()
			if userUuid == "" {
				userUuid = uuid.New().String()
				storeUserUUID(userUuid)
			}
		},
	}
)

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
