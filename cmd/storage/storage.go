package storage

import (
	"github.com/spf13/cobra"
	"gitlab.com/convolv/convolv/internal/cli"
)

func NewCmdStorage(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "storage <command>",
		Short:   "Connect, view, and remove storage systems.",
		Long:    "Connect, view, and remove storage systems such as Lustre, Weka, Ceph.",
		GroupID: "all",
		Run: func(cmd *cobra.Command, args []string) {
			return
		},
	}

	return cmd
}
