package main

import (
	"os"

	"github.com/redhat-appstudio/rhtap-cli/pkg/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Cmd().Execute(); err != nil {
		os.Exit(1)
	}
}
