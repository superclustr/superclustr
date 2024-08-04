package monitor

import (
	"github.com/spf13/cobra"
	"gitlab.com/convolv/convolv/internal/cli"
)

func NewCmdMonitor(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "monitor <command>",
		Short:   "Add, view, and remove monitoring nodes.",
		Long:    "Add, view, and remove monitoring nodes in the cluster.",
		GroupID: "all",
		Run: func(cmd *cobra.Command, args []string) {
			return
		},
	}

	return cmd
}
