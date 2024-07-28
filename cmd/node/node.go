package node

import (
	cmdAdd "gitlab.com/convolv/convolv/cmd/node/add"
	"gitlab.com/convolv/convolv/internal/cli"
	"github.com/spf13/cobra"
)

func NewCmdNode(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "node <command>",
		Short:   "View details about workflow runs",
		Long:    "List, view, and watch recent workflow runs from GitHub Actions.",
		GroupID: "actions",
	}
	cmdutil.EnableRepoOverride(cmd, f)

	cmd.AddCommand(cmdAdd.NewCmdAdd(f, nil))

	return cmd
}
