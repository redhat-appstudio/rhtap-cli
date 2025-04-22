package main

import (
	"os"

	"github.com/redhat-appstudio/rhtap-cli/pkg/cmd"
)

func main() {
	c, err := cmd.NewRootCmd()
	if err != nil {
		os.Exit(1)
	}
	if err = c.Cmd().Execute(); err != nil {
		os.Exit(1)
	}
}
