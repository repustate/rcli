package cmd

import (
	"fmt"
	"io/ioutil"
	"strings"

	"github.com/abiosoft/ishell"

	api "github.com/repustate/cli/repustate-client/v4"
)

func NewIndexCmd(c *api.Client) *ishell.Cmd {
	indexCmd := &ishell.Cmd{
		Name:     "index",
		Help:     "index document for deep search",
		LongHelp: ``,
	}

	indexCmd.AddCmd(&ishell.Cmd{
		Name:    "file",
		Aliases: []string{"f"},
		Help:    "index document from file",
		Func: func(ctx *ishell.Context) {
			if len(ctx.Args) == 0 {
				ctx.Println(colorRed("missing filename"))
				return
			}
			// index file content
			data, err := ioutil.ReadFile(ctx.Args[0]) // just pass the file name
			if err != nil {
				msg := fmt.Sprintf("failed read file: %v", err)
				ctx.Println(colorRed(msg))
				return
			}

			err = doIndex(c, string(data))
			printIndexResult(ctx, err)
		},
	})

	indexCmd.AddCmd(&ishell.Cmd{
		Name:    "text",
		Aliases: []string{"t"},
		Help:    "index input text",
		Func: func(ctx *ishell.Context) {
			if len(ctx.Args) == 0 {
				ctx.Println(colorRed("missing text"))
				return
			}
			text := strings.Join(ctx.Args, " ")
			err := doIndex(c, text)
			printIndexResult(ctx, err)
		},
	})

	return indexCmd
}

func doIndex(c *api.Client, text string) error {
	user, err := loadUser()
	if err != nil {
		return err
	}

	return c.Index(text, "", user)
}

func printIndexResult(ctx *ishell.Context, err error) {
	if err != nil {
		msg := fmt.Sprintf("Failed index document: %v", err)
		ctx.Println(colorRed(msg))
	} else {
		ctx.Println(colorBlue("Document successfully indexed"))
	}
}
