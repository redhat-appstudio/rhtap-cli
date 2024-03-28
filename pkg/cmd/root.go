package cmd

import (
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

// Cmd exposes the root command, while instantiating the subcommand and their
// requirements.
func (r *RootCmd) Cmd() *cobra.Command {
	logger := r.flags.GetLogger(os.Stdout)

	r.cmd.AddCommand(subcmd.NewDeveloperHub(logger, r.cfg, r.kube))

	for _, sub := range []subcmd.Interface{
		subcmd.NewDeploy(logger, r.flags, &r.cfg.Installer, r.kube),
		subcmd.NewTemplate(logger, r.flags, &r.cfg.Installer, r.kube),
	} {
		r.cmd.AddCommand(subcmd.NewRunner(sub).Cmd())
	}
	return r.cmd
}

// NewRootCmd instantiates the root command, setting up the global flags.
func NewRootCmd() *RootCmd {
	f := flags.NewFlags()
	cfg := config.NewConfig()
	r := &RootCmd{
		flags: f,
		cmd: &cobra.Command{
			Use:   AppName,
			Short: "RHTAP Installer CLI",
			PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
				return cfg.UnmarshalYAML()
			},
		},
		cfg:  cfg,
		kube: k8s.NewKube(f),
	}
	p := r.cmd.PersistentFlags()
	r.flags.PersistentFlags(p)
	r.cfg.PersistentFlags(p)
	return r
}
