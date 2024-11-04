package node

import (
	"github.com/spf13/cobra"
	cmdInit "github.com/superclustr/superclustr/cmd/compute/init"
	"github.com/superclustr/superclustr/internal/cli"
)

func NewCmdCompute(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "compute <action>",
		Short:   "Initialize, manage, and update a compute service.",
		Long:    "Initialize, manage, and update a compute service on this machine.",
		GroupID: "all",
	}

	cmd.AddCommand(cmdInit.NewCmdInit(f))

	return cmd
}
