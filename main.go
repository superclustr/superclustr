package main

import (
	"os"
	"embed"
	
	"gitlab.com/convolv/convolv/internal/build"
	"gitlab.com/convolv/convolv/internal/cli"
	"gitlab.com/convolv/convolv/cmd/root"
	"gitlab.com/convolv/convolv/utils"
)

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

	cmdFactory := NewFactory(buildVersion)
	stderr := cmdFactory.IOStreams.ErrOut

	ctx := context.Background()

	if cfg, err := cmdFactory.Config(); err == nil {
		var m migration.MultiAccount
		if err := cfg.Migrate(m); err != nil {
			fmt.Fprintln(stderr, err)
			return exitError
		}
	}

	updateCtx, updateCancel := context.WithCancel(ctx)
	defer updateCancel()
	updateMessageChan := make(chan *update.ReleaseInfo)
	go func() {
		rel, err := checkForUpdate(updateCtx, cmdFactory, buildVersion)
		if err != nil && hasDebug {
			fmt.Fprintf(stderr, "warning: checking for update failed: %v", err)
		}
		updateMessageChan <- rel
	}()

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

	// translate `gh help <command>` to `gh <command> --help` for extensions.
	if len(expandedArgs) >= 2 && expandedArgs[0] == "help" && isExtensionCommand(rootCmd, expandedArgs[1:]) {
		expandedArgs = expandedArgs[1:]
		expandedArgs = append(expandedArgs, "--help")
	}

	rootCmd.SetArgs(expandedArgs)

	if cmd, err := rootCmd.ExecuteContextC(ctx); err != nil {
		var pagerPipeError *iostreams.ErrClosedPagerPipe
		var noResultsError cli.NoResultsError
		var extError *root.ExternalCommandExitError
		var authError *root.AuthError
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
		} else if errors.As(err, &authError) {
			return exitAuth
		} else if errors.As(err, &pagerPipeError) {
			// ignore the error raised when piping to a closed pager
			return exitOK
		} else if errors.As(err, &noResultsError) {
			if cmdFactory.IOStreams.IsStdoutTTY() {
				fmt.Fprintln(stderr, noResultsError.Error())
			}
			// no results is not a command failure
			return exitOK
		} else if errors.As(err, &extError) {
			// pass on exit codes from extensions and shell aliases
			return exitCode(extError.ExitCode())
		}

		printError(stderr, err, cmd, hasDebug)

		if strings.Contains(err.Error(), "Incorrect function") {
			fmt.Fprintln(stderr, "You appear to be running in MinTTY without pseudo terminal support.")
			fmt.Fprintln(stderr, "To learn about workarounds for this error, run:  gh help mintty")
			return exitError
		}

		var httpErr api.HTTPError
		if errors.As(err, &httpErr) && httpErr.StatusCode == 401 {
			fmt.Fprintln(stderr, "Try authenticating with:  gh auth login")
		} else if u := factory.SSOURL(); u != "" {
			// handles organization SAML enforcement error
			fmt.Fprintf(stderr, "Authorize in your web browser:  %s\n", u)
		} else if msg := httpErr.ScopesSuggestion(); msg != "" {
			fmt.Fprintln(stderr, msg)
		}

		return exitError
	}
	if root.HasFailed() {
		return exitError
	}
}