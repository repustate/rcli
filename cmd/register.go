package cmd

import (
	"fmt"

	"github.com/abiosoft/ishell"

	api "github.com/repustate/cli/repustate-client/v4"
)

func NewRegisterCmd(c *api.Client) *ishell.Cmd {
	return &ishell.Cmd{
		Name: "register",
		Func: func(ctx *ishell.Context) {
			ctx.ShowPrompt(false)
			defer ctx.ShowPrompt(true)

			// prompt for input
			ctx.Println("Please enter a username and hit enter:")
			username := ctx.ReadLine()

			// do register
			err := doRegister(c, username)
			if err != nil {
				msg := fmt.Sprintf("Failed register user %q: %v", username, err)
				ctx.Println(colorRed(msg))
			} else {
				ctx.Println(colorBlue("Congratulations! " +
					"You’re registered and are now ready to use " +
					"Repustate’s semantic search demo"))
			}
		},
		Help: "registers user for demo",
	}
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
