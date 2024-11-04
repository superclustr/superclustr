package cli

import (
	"io/fs"

	"github.com/superclustr/superclustr/internal/iostreams"
	"github.com/superclustr/superclustr/internal/prompter"
	"github.com/superclustr/superclustr/internal/python"
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
		ExecutableName: "super",
	}

	f.IOStreams = io
	f.Prompter = prompter.New("", io.In, io.Out, io.ErrOut)
	f.Roles = roles
	f.Python = python

	return f
}
