package root

import (
	"github.com/spf13/cobra"
	initCmd "github.com/superclustr/superclustr/cmd/init"
	versionCmd "github.com/superclustr/superclustr/cmd/version"
	joinCmd "github.com/superclustr/superclustr/cmd/join"
	"github.com/superclustr/superclustr/internal/cli"
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
		Use:   "super <action> [flags]",
		Short: "SUPERCLUSTR",
		Long:  `A Simple Computing Cluster for Experimental Internet Research.`,
		Annotations: map[string]string{
			"versionInfo": versionCmd.Format(version, buildDate),
		},
	}

	cmd.PersistentFlags().Bool("help", false, "Show help for command")
	cmd.PersistentFlags().Bool("version", false, "Show version")

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
	cmd.AddCommand(initCmd.NewCmdInit(f))
	cmd.AddCommand(joinCmd.NewCmdJoin(f))

	// Add the completion command and hide it
	completionCmd := &cobra.Command{
		Use:    "completion",
		Hidden: true, // Hide the completion command
	}
	cmd.AddCommand(completionCmd)

	return cmd, nil
}
