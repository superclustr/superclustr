package node

import (
	"github.com/spf13/cobra"
	cmdAdd "gitlab.com/convolv/convolv/cmd/compute/add"
	"gitlab.com/convolv/convolv/internal/cli"
)

func NewCmdCompute(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "compute <command>",
		Short:   "Add, view, and remove compute nodes.",
		Long:    "Add, view, and remove compute nodes in the cluster.",
		GroupID: "all",
	}

	cmd.AddCommand(cmdAdd.NewCmdAdd(f, nil))

	return cmd
}
