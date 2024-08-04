package add

import (
	"github.com/spf13/cobra"
	"gitlab.com/convolv/convolv/internal/cli"
)

type AddOptions struct {
	Title string
}

func NewCmdAdd(f *cli.Factory, runF func(*AddOptions) error) *cobra.Command {
	opts := &AddOptions{
		Title: "wow",
	}

	cmd := &cobra.Command{
		Use:   "add [<key-file>]",
		Short: "Add an SSH key to your GitHub account",
		Args:  cobra.MaximumNArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			if runF != nil {
				runF(opts)
			}
		},
	}

	cmd.Flags().StringVarP(&opts.Title, "title", "t", "", "Title for the new key")
	return cmd
}
