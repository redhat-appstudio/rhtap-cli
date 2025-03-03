package cmd

import (
	"os"

	"github.com/redhat-appstudio/rhtap-cli/pkg/chartfs"
	"github.com/redhat-appstudio/rhtap-cli/pkg/config"
	"github.com/redhat-appstudio/rhtap-cli/pkg/constants"
	"github.com/redhat-appstudio/rhtap-cli/pkg/flags"
	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"
	"github.com/redhat-appstudio/rhtap-cli/pkg/subcmd"

	"github.com/spf13/cobra"
)

// RootCmd is the root command.
type RootCmd struct {
	cmd   *cobra.Command   // root command
	flags *flags.Flags     // global flags
	cfg   *config.Config   // installer configuration
	cfs   *chartfs.ChartFS // embedded filesystem
	kube  *k8s.Kube        // kubernetes client
}

// Cmd exposes the root command, while instantiating the subcommand and their
// requirements.
func (r *RootCmd) Cmd() *cobra.Command {
	logger := r.flags.GetLogger(os.Stdout)

	// TODO: Remove me.
	r.cmd.AddCommand(subcmd.NewIntegration(logger, r.cfg, r.kube))

	for _, sub := range []subcmd.Interface{
		subcmd.NewDeploy(logger, r.flags, r.cfg, r.cfs, r.kube),
		subcmd.NewTemplate(logger, r.flags, r.cfg, r.cfs, r.kube),
		subcmd.NewInstaller(r.flags),
	} {
		r.cmd.AddCommand(subcmd.NewRunner(sub).Cmd())
	}
	return r.cmd
}

// NewRootCmd instantiates the root command, setting up the global flags.
func NewRootCmd() (*RootCmd, error) {
	f := flags.NewFlags()

	cfs, err := chartfs.NewChartFSForCWD()
	if err != nil {
		return nil, err
	}

	cfg := config.NewConfig(cfs)
	r := &RootCmd{
		flags: f,
		cmd: &cobra.Command{
			Use:   constants.AppName,
			Short: "RHTAP Installer CLI",
			PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
				return cfg.UnmarshalYAML()
			},
			SilenceUsage: true,
		},
		cfg:  cfg,
		cfs:  cfs,
		kube: k8s.NewKube(f),
	}
	p := r.cmd.PersistentFlags()
	r.flags.PersistentFlags(p)
	r.cfg.PersistentFlags(p)
	return r, nil
}
