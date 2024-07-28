package root

import (
    "embed"
    "fmt"
    "io/fs"
    "io/ioutil"
    "os"
    "os/exec"
    "path/filepath"

    "github.com/spf13/cobra"
)