package init

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"

	"github.com/apenella/go-ansible/v2/pkg/execute"
	"github.com/apenella/go-ansible/v2/pkg/execute/configuration"
	"github.com/apenella/go-ansible/v2/pkg/execute/result/transformer"
	"github.com/apenella/go-ansible/v2/pkg/playbook"
	"github.com/spf13/cobra"
	"github.com/superclustr/superclustr/internal/cli"
)

func NewCmdInit(f *cli.Factory) *cobra.Command {
	var device string
	var hostname string
	var ipPool string
	var ipAddr string
	var ipNetmask string
	var ipGateway string
	var ipV6Pool string
	var ipV6Addr string
	var ipV6Gateway string

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize a master service.",
		Long:  "Initialize a master service on this machine.",
		Run: func(cmd *cobra.Command, args []string) {
			err := runInit(f, device, hostname, ipPool, ipAddr, ipNetmask, ipGateway, ipV6Pool, ipV6Addr, ipV6Gateway)
			if err != nil {
				log.Fatalf("init command failed: %v", err)
			}
		},
	}

	// Define flags for network configuration
	cmd.Flags().StringVar(&device, "device", "", "Network Interface Device Name (e.g. 'eth0')")
	cmd.Flags().StringVar(&hostname, "hostname", "", "Hostname (e.g. 'node01.ams.superclustr.net')")
	cmd.Flags().StringVar(&ipPool, "ip-pool", "", "LoadBalancer IP pool range (e.g., '192.168.1.240/25')")
	cmd.Flags().StringVar(&ipAddr, "ip-address", "", "Static IP address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipNetmask, "ip-netmask", "", "IP netmask (required if ip-address is static)")
	cmd.Flags().StringVar(&ipGateway, "ip-gateway", "", "Gateway IP address (required if ip-address is static)")
	cmd.Flags().StringVar(&ipV6Pool, "ip-v6-pool", "", "LoadBalancer IPv6 pool range (e.g., '2001:678:7ec:70::1/64')")
	cmd.Flags().StringVar(&ipV6Addr, "ip-v6-address", "", "Static IPv6 address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipV6Gateway, "ip-v6-gateway", "", "IPv6 Gateway IP address (required if ip-v6-address is static)")
	return cmd
}

func runInit(f *cli.Factory, device string, hostname string, ipPool string, ipAddr string, ipNetmask string, ipGateway string, ipV6Pool string, ipV6Addr string, ipV6Gateway string) error {
	// Validate inputs
	if device == "" {
		return fmt.Errorf("Network Device is required")
	}
	if hostname == "" {
		return fmt.Errorf("Hostname is required")
	}
	if ipPool == "" || ipV6Pool == "" {
		return fmt.Errorf("LoadBalancer pool range is required")
	}
	if ipAddr == "" || ipV6Addr == "" {
		return fmt.Errorf("Machine IP address or 'dhcp' is required")
	}
	if ipNetmask == "" && ipAddr != "dhcp" {
		return fmt.Errorf("Netmask is required, since ip-address is static")
	}
	if (ipGateway == "" || ipV6Gateway == "") && (ipAddr != "dhcp" || ipV6Addr != "dhcp") {
		return fmt.Errorf("Gateway IP address is required, since ip-address is static")
	}

	// Helper function to filter empty values
	filterEmpty := func(m map[string]string) map[string]string {
		result := make(map[string]string)
		for k, v := range m {
			if v != "" {
				result[k] = v
			}
		}
		return result
	}

	// Build playbook structure
	yamlData, err := yaml.Marshal([]interface{}{map[string]interface{}{
		"hosts":        "localhost",
		"become":       true,
		"gather_facts": true,
		"roles": []map[string]interface{}{{
			"role": "master",
			"master_network": filterEmpty(map[string]string{
				"device": 		 device,
				"hostname": 	 hostname,
				"ip_pool":       ipPool,
				"ip_address":    ipAddr,
				"ip_gateway":    ipGateway,
				"ip_netmask":    ipNetmask,
				"ip_v6_pool":    ipV6Pool,
				"ip_v6_address": ipV6Addr,
				"ip_v6_gateway": ipV6Gateway,
			}),
		}},
	}})
	if err != nil {
		return fmt.Errorf("failed to generate playbook YAML: %v", err)
	}

	// Define inventory on the fly
	inventoryIni := ``

	// Define playbook on the fly
	playbookYaml := string(yamlData)

	// Create a temporary directory to store the inventory and playbook
	tempDir, err := os.MkdirTemp("", "ansible")
	if err != nil {
		return fmt.Errorf("failed to create temporary directory: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Write inventory and playbook to the temporary directory
	inventoryFile := filepath.Join(f.Python.GetRolesFsPath(), "inventory.ini")
	playbookFile := filepath.Join(f.Python.GetRolesFsPath(), "playbook.yml")

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
				transformer.Prepend("master"),
			),
			execute.WithEnvVars(map[string]string{"PYTHONPATH": f.Python.GetPythonLibFsPath()}),
			execute.WithExecutable(f.Python),
		),
		configuration.WithAnsibleForceColor(),
		configuration.WithAnsibleRolesPath(f.Python.GetRolesFsPath()),
	)

	// Execute the playbook
	err = exec.Execute(context.Background())
	if err != nil {
		return fmt.Errorf("failed to execute ansible playbook: %v", err)
	}

	return nil
}
