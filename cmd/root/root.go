package root

import (
	"github.com/spf13/cobra"
	computeCmd "gitlab.com/convolv/convolv/cmd/compute"
	masterCmd "gitlab.com/convolv/convolv/cmd/master"
	monitorCmd "gitlab.com/convolv/convolv/cmd/monitor"
	storageCmd "gitlab.com/convolv/convolv/cmd/storage"
	versionCmd "gitlab.com/convolv/convolv/cmd/version"
	"gitlab.com/convolv/convolv/internal/cli"
)

type AuthError struct {
	err error
}

func (ae *AuthError) Error() string {
	return ae.err.Error()
}

func NewCmdRoot(f *cli.Factory, version, buildDate string) (*cobra.Command, error) {
	cobra.EnableCommandSorting = false
	cmd := &cobra.Command{
		Use:   "convolv <service> <action> [flags]",
		Short: "Convolv CLI",
		Long:  `The Secure End-To-End AI Workspace for Organizations.`,
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
		Title: "Commands",
	})

	// Child commands
	cmd.AddCommand(versionCmd.NewCmdVersion(f, version, buildDate))
	cmd.AddCommand(masterCmd.NewCmdMaster(f))
	cmd.AddCommand(computeCmd.NewCmdCompute(f))
	cmd.AddCommand(monitorCmd.NewCmdMonitor(f))
	cmd.AddCommand(storageCmd.NewCmdStorage(f))

	// Add the completion command and hide it
	completionCmd := &cobra.Command{
		Use:    "completion",
		Hidden: true, // Hide the completion command
	}
	cmd.AddCommand(completionCmd)

	return cmd, nil
}
