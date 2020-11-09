package cmd

import (
	"bufio"
	"fmt"
	"github.com/spf13/cobra"
	"os"
	"strings"

	api "github.com/repustate/cli/api-client/v4"
)

// registerCmd represents the register command

func newRegisterCmd(c *api.Client) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "register",
		Short: "Registers user for demo",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Please enter a username and hit enter:")
			reader := bufio.NewReader(os.Stdin)
			username, err := reader.ReadString('\n')
			if err != nil {
				msg := fmt.Sprintf("Bad input: %v", err)
				fmt.Println(colorRed(msg))
				return
			}

			username = strings.TrimSuffix(username, "\n")
			username = strings.TrimSuffix(username, "\r")

			err = doRegister(c, username)
			if err != nil {
				msg := fmt.Sprintf("Failed register user %q: %v", username, err)
				fmt.Println(colorRed(msg))
			} else {
				fmt.Println(colorBlue("Congratulations! " +
					"You’re registered and are now ready to use " +
					"Repustate’s semantic search demo"))
			}
		},
	}

	cmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")

	return cmd
}

func doRegister(c *api.Client, username string) error {
	// validate username
	if err := validateUsername(username); err != nil {
		return fmt.Errorf("invalid username: %v", err)
	}

	// register user on server
	if err := c.Register(username); err != nil {
		return err
	}

	// store username in profile file
	if err := storeUser(username); err != nil {
		return fmt.Errorf("failed store username: %v", err)
	}

	return nil
}
