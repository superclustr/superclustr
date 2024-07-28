package root

import (
	versionCmd "gitlab.com/convolv/convolv/cmd/version"
	nodeCmd "gitlab.com/convolv/convolv/cmd/node"
	"gitlab.com/convolv/convolv/internal/cli"
	"github.com/MakeNowJust/heredoc"
	"github.com/spf13/cobra"
)

type AuthError struct {
	err error
}

func (ae *AuthError) Error() string {
	return ae.err.Error()
}

func NewCmdRoot(f *cli.Factory, version, buildDate string) (*cobra.Command, error) {
	cmd := &cobra.Command{
		Use:   "gh <command> <subcommand> [flags]",
		Short: "Convolv CLI",
		Long:  `The Secure End-To-End AI Workspace for Organizations.`,
		Example: heredoc.Doc(`
			$ convolv init
			$ convolv node add
			$ convolv node list
		`),
		Annotations: map[string]string{
			"versionInfo": versionCmd.Format(version, buildDate),
		},
	}

	cmd.PersistentFlags().Bool("help", false, "Show help for command")
	cmd.PersistentFlags().Bool("version", false, "Show convolv version")

	cmd.SilenceErrors = true
	cmd.SilenceUsage = true

	cmd.SetHelpFunc(func(c *cobra.Command, args []string) {
		rootHelpFunc(f, c, args)
	})
	cmd.SetUsageFunc(func(c *cobra.Command) error {
		return rootUsageFunc(f.IOStreams.ErrOut, c)
	})
	cmd.SetFlagErrorFunc(rootFlagErrorFunc)

	cmd.AddGroup(&cobra.Group{
		ID:    "all",
		Title: "Available commands",
	})

	// Child commands
	cmd.AddCommand(versionCmd.NewCmdVersion(f, version, buildDate))
	cmd.AddCommand(nodeCmd.NewCmdNode(f))

	return cmd, nil
}
