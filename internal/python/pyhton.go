package python

import (
	"context"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/apenella/go-ansible/v2/pkg/execute/exec"
	"github.com/kluctl/go-embed-python/embed_util"
	"github.com/kluctl/go-embed-python/python"
)

type PythonExec struct {
	ep              *python.EmbeddedPython
	pythonLibFsPath string
	rolesFsPath     string
}

func NewPythonExec(roles fs.FS, data fs.FS) *PythonExec {

	tmpDir := filepath.Join(os.TempDir(), "go-ansible")
	pythonDir := tmpDir + "-python"
	pythonLibDir := tmpDir + "-python-lib"
	rolesDir := tmpDir + "-roles"

	pythonLibFs, _ := embed_util.NewEmbeddedFilesWithTmpDir(data, pythonLibDir, true)
	pythonLibFsPath := pythonLibFs.GetExtractedPath()
	rolesFs, _ := embed_util.NewEmbeddedFilesWithTmpDir(roles, rolesDir, true)
	rolesFsPath := rolesFs.GetExtractedPath()

	ep, _ := python.NewEmbeddedPythonWithTmpDir(pythonDir, true)
	ep.AddPythonPath(pythonLibFs.GetExtractedPath())
	ep.AddPythonPath(rolesFs.GetExtractedPath())

	return &PythonExec{
		ep:              ep,
		pythonLibFsPath: pythonLibFsPath,
		rolesFsPath:     rolesFsPath,
	}
}

// Getter method for rolesFsPath
func (e *PythonExec) GetRolesFsPath() string {
	return e.rolesFsPath
}

// Getter method for pythonLibFsPath
func (e *PythonExec) GetPythonLibFsPath() string {
	return e.pythonLibFsPath
}

// Command is a wrapper of exec.Command
func (e *PythonExec) Command(name string, arg ...string) exec.Cmder {
	cmd := append([]string{name}, arg...)
	execCmd, _ := e.ep.PythonCmd2(cmd)
	return execCmd
}

// CommandContext is a wrapper of exec.CommandContext
func (e *PythonExec) CommandContext(ctx context.Context, name string, arg ...string) exec.Cmder {
	cmd := append([]string{name}, arg...)
	execCmd, _ := e.ep.PythonCmd2(cmd)
	return execCmd
}
