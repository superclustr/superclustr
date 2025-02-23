package worker

import (
	"github.com/spf13/cobra"
	cmdInit "github.com/superclustr/superclustr/cmd/worker/init"
	"github.com/superclustr/superclustr/internal/cli"
)

func NewCmdWorker(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "worker <action>",
		Short:   "Initialize, manage, and update a worker machine.",
		Long:    "Initialize, manage, and update a worker service on this machine.",
		GroupID: "all",
	}

	cmd.AddCommand(cmdInit.NewCmdInit(f))

	return cmd
}
