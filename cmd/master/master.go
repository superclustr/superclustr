package node

import (
	"github.com/spf13/cobra"
	cmdInit "github.com/superclustr/superclustr/cmd/master/init"
	"github.com/superclustr/superclustr/internal/cli"
)

func NewCmdMaster(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "master <action>",
		Short:   "Initialize, manage, and update a master service.",
		Long:    "Initialize, manage, and update a master service on this machine.",
		GroupID: "all",
	}

	cmd.AddCommand(cmdInit.NewCmdInit(f))

	return cmd
}
