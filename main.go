package main

import (
	"context"
	"embed"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	surveyCore "github.com/AlecAivazis/survey/v2/core"
	"github.com/AlecAivazis/survey/v2/terminal"
	"github.com/mgutz/ansi"
	"github.com/spf13/cobra"
	"gitlab.com/convolv/convolv/cmd/root"
	"gitlab.com/convolv/convolv/internal/build"
	"gitlab.com/convolv/convolv/internal/cli"
	"gitlab.com/convolv/convolv/internal/iostreams"
	"gitlab.com/convolv/convolv/internal/python"
	"gitlab.com/convolv/convolv/utils"
)

//go:generate go run ./generate/pip

//go:embed ansible/*
var ansible embed.FS

type exitCode int

const (
	exitOK      exitCode = 0
	exitError   exitCode = 1
	exitCancel  exitCode = 2
	exitAuth    exitCode = 4
	exitPending exitCode = 8
)

func main() {
	code := mainRun()
	os.Exit(int(code))
}

func mainRun() exitCode {
	buildDate := build.Date
	buildVersion := build.Version
	hasDebug, _ := utils.IsDebugEnabled()
	python := python.NewPythonExec(ansible, data)

	cmdFactory := cli.New(buildVersion, ansible, python)
	stderr := cmdFactory.IOStreams.ErrOut

	ctx := context.Background()

	if !cmdFactory.IOStreams.ColorEnabled() {
		surveyCore.DisableColor = true
		ansi.DisableColors(true)
	} else {
		// override survey's poor choice of color
		surveyCore.TemplateFuncsWithColor["color"] = func(style string) string {
			switch style {
			case "white":
				return ansi.ColorCode("default")
			default:
				return ansi.ColorCode(style)
			}
		}
	}

	rootCmd, err := root.NewCmdRoot(cmdFactory, buildVersion, buildDate)
	if err != nil {
		fmt.Fprintf(stderr, "failed to create root command: %s\n", err)
		return exitError
	}

	expandedArgs := []string{}
	if len(os.Args) > 0 {
		expandedArgs = os.Args[1:]
	}

	rootCmd.SetArgs(expandedArgs)

	if cmd, err := rootCmd.ExecuteContextC(ctx); err != nil {
		var pagerPipeError *iostreams.ErrClosedPagerPipe
		var noResultsError cli.NoResultsError
		if err == cli.SilentError {
			return exitError
		} else if err == cli.PendingError {
			return exitPending
		} else if cli.IsUserCancellation(err) {
			if errors.Is(err, terminal.InterruptErr) {
				// ensure the next shell prompt will start on its own line
				fmt.Fprint(stderr, "\n")
			}
			return exitCancel
		} else if errors.As(err, &pagerPipeError) {
			// ignore the error raised when piping to a closed pager
			return exitOK
		} else if errors.As(err, &noResultsError) {
			if cmdFactory.IOStreams.IsStdoutTTY() {
				fmt.Fprintln(stderr, noResultsError.Error())
			}
			// no results is not a command failure
			return exitOK
		}

		printError(stderr, err, cmd, hasDebug)

		return exitError
	}

	if root.HasFailed() {
		return exitError
	}

	return exitOK
}

func printError(out io.Writer, err error, cmd *cobra.Command, debug bool) {
	fmt.Fprintln(out, err)

	var flagError *cli.FlagError
	if errors.As(err, &flagError) || strings.HasPrefix(err.Error(), "unknown command ") {
		if !strings.HasSuffix(err.Error(), "\n") {
			fmt.Fprintln(out)
		}
		fmt.Fprintln(out, cmd.UsageString())
	}
}
