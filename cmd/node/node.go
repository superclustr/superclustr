package node

import (
	cmdAdd "gitlab.com/convolv/convolv/cmd/node/add"
	"github.com/cli/cli/v2/pkg/cmdutil"
	"github.com/spf13/cobra"
)

func NewCmdNode(f *cmdutil.Factory) *cobra.Command {
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
