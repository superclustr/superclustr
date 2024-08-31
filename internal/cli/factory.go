package cli

import (
	"io/fs"

	"gitlab.com/convolv/convolv/internal/iostreams"
	"gitlab.com/convolv/convolv/internal/prompter"
	"gitlab.com/convolv/convolv/internal/python"
)

type Factory struct {
	AppVersion     string
	ExecutableName string

	IOStreams *iostreams.IOStreams
	Prompter  prompter.Prompter
	Roles     fs.FS
	Python    *python.PythonExec
}

func New(appVersion string, roles fs.FS, python *python.PythonExec) *Factory {
	io := iostreams.System()

	f := &Factory{
		AppVersion:     appVersion,
		ExecutableName: "convolv",
	}

	f.IOStreams = io
	f.Prompter = prompter.New("", io.In, io.Out, io.ErrOut)
	f.Roles = roles
	f.Python = python

	return f
}
