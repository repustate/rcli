package main

import (
	"github.com/abiosoft/ishell"
	"github.com/fatih/color"

	"github.com/repustate/cli/cmd"
	client "github.com/repustate/cli/repustate-client/v4"
)

func main() {
	shell := ishell.New()
	shell.Println("Repustate DeepSearch CLI")

	api, err := client.New()
	if err != nil {
		fatal(shell, err)
	}

	// disable 'clear' command installed by default
	shell.DeleteCmd("clear")

	// install user-defined commands
	for _, cmd := range []*ishell.Cmd{
		cmd.NewRegisterCmd(&api),
		cmd.NewIndexCmd(&api),
		cmd.NewSearchCmd(&api),
	} {
		shell.AddCmd(cmd)
	}

	// start shell
	shell.Run()
	// teardown when finished
	shell.Close()
}

func fatal(shell *ishell.Shell, err error) {
	msg := color.New(color.FgRed).Sprint(err)
	shell.Println(msg)
	shell.Close()
}
