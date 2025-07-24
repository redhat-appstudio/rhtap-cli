package main

import (
	"os"

	"github.com/redhat-appstudio/tssc/pkg/cmd"
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
