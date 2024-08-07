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
	Ansible   fs.FS
	Python    *python.PythonExec
}

func New(appVersion string, ansible fs.FS, python *python.PythonExec) *Factory {
	io := iostreams.System()

	f := &Factory{
		AppVersion:     appVersion,
		ExecutableName: "convolv",
	}

	f.IOStreams = io
	f.Prompter = prompter.New("", io.In, io.Out, io.ErrOut)
	f.Ansible = ansible
	f.Python = python

	return f
}
