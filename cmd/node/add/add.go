package add

import (
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/spf13/cobra"
)

func NewCmdAdd(f *cmdutil.Factory, runF func(*AddOptions) error) *cobra.Command {

	cmd := &cobra.Command{
		Use:   "add [<key-file>]",
		Short: "Add an SSH key to your GitHub account",
		Args:  cobra.MaximumNArgs(1),
	}

	typeEnums := []string{shared.AuthenticationKey, shared.SigningKey}
	cmdutil.StringEnumFlag(cmd, &opts.Type, "type", "", shared.AuthenticationKey, typeEnums, "Type of the ssh key")
	cmd.Flags().StringVarP(&opts.Title, "title", "t", "", "Title for the new key")
	return cmd
}