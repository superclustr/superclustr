package python

import (
	"io/fs"
	"os"
	"path/filepath"

	"github.com/kluctl/go-embed-python/embed_util"
	"github.com/kluctl/go-embed-python/python"
)

type PythonExec struct {
	ep              *python.EmbeddedPython
	pythonLibFsPath string
	resourcesFsPath string
}

func NewPythonExec(ansible *fs.FS, data *fs.FS) *PythonExec {

	tmpDir := filepath.Join(os.TempDir(), "go-ansible")
	pythonDir := tmpDir + "-python"
	pythonLibDir := tmpDir + "-python-lib"
	resourcesDir := tmpDir + "-resources"

	pythonLibFs, _ := embed_util.NewEmbeddedFilesWithTmpDir(*data.Data, pythonLibDir, true)
	pythonLibFsPath := pythonLibFs.GetExtractedPath()
	resourcesFs, _ := embed_util.NewEmbeddedFilesWithTmpDir(*ansible, resourcesDir, true)
	resourcesFsPath := resourcesFs.GetExtractedPath()

	ep, _ := python.NewEmbeddedPythonWithTmpDir(pythonDir, true)
	ep.AddPythonPath(pythonLibFs.GetExtractedPath())
	ep.AddPythonPath(resourcesFs.GetExtractedPath())

	return &PythonExec{
		ep:              ep,
		pythonLibFsPath: pythonLibFsPath,
		resourcesFsPath: resourcesFsPath,
	}
}
