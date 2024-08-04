package init

import (
	"context"
	"fmt"
	"io/fs"
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
		Use:     "init",
		Short:   "Initialize a new head node.",
		Long:    "Initialize a new head node on this machine.",
		GroupID: "all",
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
openhpc-login-0 ansible_host=88.99.165.60 ansible_user=centos

[openhpc_compute]
openhpc-compute-0 ansible_host=88.99.165.60 ansible_user=centos

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
      openhpc_slurm_service_enabled: true
      openhpc_slurm_control_host: "{{ groups['cluster_control'] | first }}"
      openhpc_slurm_partitions:
        - name: "compute"
      openhpc_cluster_name: openhpc
      openhpc_packages: []
`

	// Create a temporary directory to store the inventory and playbook
	tempDir, err := os.MkdirTemp("", "ansible")
	if err != nil {
		return fmt.Errorf("failed to create temporary directory: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Write inventory and playbook to the temporary directory
	inventoryFile := tempDir + "/inventory.ini"
	playbookFile := tempDir + "/playbook.yml"

	err = os.WriteFile(inventoryFile, []byte(inventoryIni), 0644)
	if err != nil {
		return fmt.Errorf("failed to write inventory file: %v", err)
	}

	err = os.WriteFile(playbookFile, []byte(playbookYaml), 0644)
	if err != nil {
		return fmt.Errorf("failed to write playbook file: %v", err)
	}

	// Extract the embedded role to the temporary directory
	rolePath := filepath.Join(tempDir, "roles", "openhpc")
	err = fs.WalkDir(f.Ansible, "ansible/openhpc", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		relPath, err := filepath.Rel("ansible/openhpc", path)
		if err != nil {
			return err
		}

		destPath := filepath.Join(rolePath, relPath)

		if d.IsDir() {
			return os.MkdirAll(destPath, 0755)
		} else {
			data, err := fs.ReadFile(f.Ansible, path)
			if err != nil {
				return err
			}

			return os.WriteFile(destPath, data, 0644)
		}
	})

	if err != nil {
		return fmt.Errorf("failed to extract role: %v", err)
	}

	ansiblePlaybookOptions := &playbook.AnsiblePlaybookOptions{
		Inventory: inventoryFile,
	}

	// Execute the ansible playbook using go-ansible
	playbookCmd := playbook.NewAnsiblePlaybookCmd(
		playbook.WithPlaybooks(playbookFile),
		playbook.WithPlaybookOptions(ansiblePlaybookOptions),
	)

	exec := configuration.NewAnsibleWithConfigurationSettingsExecute(
		execute.NewDefaultExecute(
			execute.WithCmd(playbookCmd),
			execute.WithErrorEnrich(playbook.NewAnsiblePlaybookErrorEnrich()),
			execute.WithTransformers(
				transformer.Prepend("Go-ansible example with become"),
			),
		),
		configuration.WithAnsibleForceColor(),
		configuration.WithAnsibleRolesPath(rolePath),
	)

	// Execute the playbook
	err = exec.Execute(context.Background())
	if err != nil {
		return fmt.Errorf("failed to execute ansible playbook: %v", err)
	}

	return nil
}
