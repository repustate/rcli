package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	client "github.com/repustate/cli/api-client/v4"
)

var cfgFile string

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "rcli",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	// Uncomment the following line if your bare application
	// has an action associated with it:
	//	Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	api, err := client.New()
	if err != nil {
		fmt.Println(colorRed(err.Error()))
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
