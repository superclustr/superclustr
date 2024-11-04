package node

import (
	"github.com/spf13/cobra"
	cmdInit "github.com/superclustr/superclustr/cmd/worker/init"
	"github.com/superclustr/superclustr/internal/cli"
)

func NewCmdCompute(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "worker <action>",
		Short:   "Initialize, manage, and update a worker service.",
		Long:    "Initialize, manage, and update a worker service on this machine.",
		GroupID: "all",
	}

	cmd.AddCommand(cmdInit.NewCmdInit(f))

	return cmd
}
