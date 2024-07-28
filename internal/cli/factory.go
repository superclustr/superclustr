package cli

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/cli/cli/v2/internal/prompter"
	"github.com/cli/cli/v2/internal/iostreams"
)

type Factory struct {
	AppVersion     string
	ExecutableName string

	IOStreams        *iostreams.IOStreams
	Prompter         prompter.Prompter
}

// Executable is the path to the currently invoked binary
func (f *Factory) Executable() string {
	if !strings.ContainsRune(f.ExecutableName, os.PathSeparator) {
		f.ExecutableName = executable(f.ExecutableName)
	}

	return f.ExecutableName
}