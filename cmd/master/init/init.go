package init

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/apenella/go-ansible/v2/pkg/execute"
	"github.com/apenella/go-ansible/v2/pkg/execute/configuration"
	"github.com/apenella/go-ansible/v2/pkg/execute/result/transformer"
	"github.com/apenella/go-ansible/v2/pkg/playbook"
	"github.com/spf13/cobra"
	"gitlab.com/convolv/convolv/internal/cli"
)

func NewCmdInit(f *cli.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize a compute service.",
		Long:  "Initialize a compute service on this machine.",
		Run: func(cmd *cobra.Command, args []string) {
			err := runInit(f)
			if err != nil {
				log.Fatalf("init command failed: %v", err)
			}
		},
	}

	return cmd
}

func runInit(f *cli.Factory) error {
	// Define inventory on the fly
	inventoryIni := `
[openhpc_login]
openhpc-login-0 ansible_host=88.99.165.60 ansible_user=root

[openhpc_compute]
openhpc-compute-0 ansible_host=88.99.165.60 ansible_user=root

[cluster_login:children]
openhpc_login

[cluster_control:children]
openhpc_login

[cluster_batch:children]
openhpc_compute
`

	// Define playbook on the fly
	playbookYaml := `
---
- hosts:
  - cluster_login
  - cluster_control
  - cluster_batch
  become: yes
  roles:
    - role: openhpc
      openhpc_enable:
        control: "{{ inventory_hostname in groups['cluster_control'] }}"
        batch: "{{ inventory_hostname in groups['cluster_batch'] }}"
        runtime: true
      openhpc_slurm_control_host: "{{ groups['cluster_control'] | first }}"
      openhpc_slurm_partitions:
        - name: "compute"
      openhpc_cluster_name: openhpc
`

	// Create a temporary directory to store the inventory and playbook
	tempDir, err := os.MkdirTemp("", "ansible")
	if err != nil {
		return fmt.Errorf("failed to create temporary directory: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Write inventory and playbook to the temporary directory
	inventoryFile := filepath.Join(f.Python.GetAnsibleFsPath(), "inventory.ini")
	playbookFile := filepath.Join(f.Python.GetAnsibleFsPath(), "playbook.yml")

	err = os.WriteFile(inventoryFile, []byte(inventoryIni), 0644)
	if err != nil {
		return fmt.Errorf("failed to write inventory file: %v", err)
	}

	err = os.WriteFile(playbookFile, []byte(playbookYaml), 0644)
	if err != nil {
		return fmt.Errorf("failed to write playbook file: %v", err)
	}

	ansiblePlaybookOptions := &playbook.AnsiblePlaybookOptions{
		Inventory: inventoryFile,
	}

	// Execute the ansible playbook using go-ansible
	playbookCmd := playbook.NewAnsiblePlaybookCmd(
		playbook.WithPlaybooks(playbookFile),
		playbook.WithPlaybookOptions(ansiblePlaybookOptions),
		playbook.WithBinary(
			filepath.Join(f.Python.GetPythonLibFsPath(), "bin", "ansible-playbook"),
		),
	)

	exec := configuration.NewAnsibleWithConfigurationSettingsExecute(
		execute.NewDefaultExecute(
			execute.WithCmd(playbookCmd),
			execute.WithErrorEnrich(playbook.NewAnsiblePlaybookErrorEnrich()),
			execute.WithTransformers(
				transformer.Prepend("Go-ansible example with become"),
			),
			execute.WithExecutable(f.Python),
		),
		configuration.WithAnsibleForceColor(),
		configuration.WithAnsibleRolesPath(f.Python.GetAnsibleFsPath()),
	)

	// Execute the playbook
	err = exec.Execute(context.Background())
	if err != nil {
		return fmt.Errorf("failed to execute ansible playbook: %v", err)
	}

	return nil
}
