package cmd

import (
	"log/slog"
	"os"

	"github.com/otaviof/rhtap-installer-cli/pkg/config"
	"github.com/otaviof/rhtap-installer-cli/pkg/flags"
	"github.com/otaviof/rhtap-installer-cli/pkg/k8s"
	"github.com/otaviof/rhtap-installer-cli/pkg/subcmd"

	"github.com/spf13/cobra"
)

const AppName = "rhtap-installer-cli"

// RootCmd is the root command.
type RootCmd struct {
	cmd   *cobra.Command // root command
	flags *flags.Flags   // global flags
	cfg   *config.Config // installer configuration
	kube  *k8s.Kube      // kubernetes client
}

// getLogger returns a logger instance.l
func (r *RootCmd) getLogger() *slog.Logger {
	logOpts := &slog.HandlerOptions{Level: r.flags.LogLevel}
	return slog.New(slog.NewTextHandler(os.Stdout, logOpts))
}

// Cmd exposes the root command.
func (r *RootCmd) Cmd() *cobra.Command {
	r.cmd.PersistentPreRunE = func(_ *cobra.Command, _ []string) error {
		return r.cfg.UnmarshalYAML()
	}

	logger := r.getLogger()
	for _, sub := range []subcmd.Interface{
		subcmd.NewBootstrap(),
		subcmd.NewDeploy(logger, r.flags, r.cfg, r.kube),
	} {
		r.cmd.AddCommand(subcmd.NewRunner(sub).Cmd())
	}
	return r.cmd
}

// NewRootCmd instantiates the root command, setting up the global flags.
func NewRootCmd() *RootCmd {
	f := flags.NewFlags()
	r := &RootCmd{
		flags: f,
		cmd: &cobra.Command{
			Use:   AppName,
			Short: "RHTAP Installer CLI",
		},
		cfg:  config.NewConfig(),
		kube: k8s.NewKube(f),
	}
	p := r.cmd.PersistentFlags()
	r.flags.PersistentFlags(p)
	r.cfg.PersistentFlags(p)
	return r
}
