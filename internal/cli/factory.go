package cli

import (
	"gitlab.com/convolv/convolv/internal/prompter"
	"gitlab.com/convolv/convolv/internal/iostreams"
)

type Factory struct {
	AppVersion     string
	ExecutableName string

	IOStreams        *iostreams.IOStreams
	Prompter         prompter.Prompter
}

func NewFactory(appVersion string) *Factory {
	io := iostreams.System()
	
	f := &Factory{
		AppVersion:     appVersion,
		ExecutableName: "convolv",
	}

	f.IOStreams = io
	f.Prompter = prompter.New("", io.In, io.Out, io.ErrOut)

	return f
}