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
	var server string
	var hostname string
	var ipAddr string
	var ipNetmask string
	var ipGateway string
	var ipV6Addr string
	var ipV6Gateway string
	var tailscaleToken string
	var kubernetesToken string

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize a worker service.",
		Long:  "Initialize a worker service on this machine.",
		Run: func(cmd *cobra.Command, args []string) {
			err := runInit(f, device, server, hostname, ipAddr, ipNetmask, ipGateway, ipV6Addr, ipV6Gateway, tailscaleToken, kubernetesToken)
			if err != nil {
				log.Fatalf("init command failed: %v", err)
			}
		},
	}

	// Define flags for network configuration
	cmd.Flags().StringVar(&device, "device", "", "Network interface device name (e.g. 'eth0')")
	cmd.Flags().StringVar(&server, "server", "", "Master server (e.g. '100.104.213.66')")
	cmd.Flags().StringVar(&hostname, "hostname", "", "Hostname (e.g. 'node02.superclustr.net')")
	cmd.Flags().StringVar(&ipAddr, "ip-address", "", "Static IP address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipNetmask, "ip-netmask", "", "IP netmask (required if ip-address is static)")
	cmd.Flags().StringVar(&ipGateway, "ip-gateway", "", "Gateway IP address (required if ip-address is static)")
	cmd.Flags().StringVar(&ipV6Addr, "ip-v6-address", "", "Static IPv6 address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipV6Gateway, "ip-v6-gateway", "", "IPv6 Gateway IP address (required if ip-v6-address is static)")
	cmd.Flags().StringVar(&tailscaleToken, "tailscale-token", "", "Tailscale authentication token (required for vpn network access)")
	cmd.Flags().StringVar(&kubernetesToken, "kubernetes-token", "", "Kubernetes node token (required for joining the cluster)")
	return cmd
}

func runInit(f *cli.Factory, device string, server string, hostname string, ipAddr string, ipNetmask string, ipGateway string, ipV6Addr string, ipV6Gateway string, tailscaleToken string, kubernetesToken string) error {
	// Validate inputs
	if server == "" {
		return fmt.Errorf("Server is required")
	}
	if kubernetesToken == "" {
		return fmt.Errorf("Kubernetes node token is required")
	}
	if tailscaleToken == "" {
		return fmt.Errorf("Tailscale authentication token is required")
	}
	if device == "" && (ipAddr != "" || ipV6Addr != "") {
		return fmt.Errorf("Network interface device must be specified")
	}
	if device != "" && (ipAddr == "" && ipV6Addr == "") {
		return fmt.Errorf("IP address is required, since device is defined")
	}
	if ipNetmask == "" && ipAddr != "dhcp" && ipAddr != "" {
		return fmt.Errorf("Netmask is required, since ip-address is static")
	}
	if (ipGateway == "" && ipAddr != "dhcp" && ipAddr != "") || (ipV6Gateway == "" && ipV6Addr != "dhcp" && ipV6Addr != "") {
		return fmt.Errorf("Gateway IP address is required, since ip-address is static")
	}

	// Build playbook structure
	yamlData, err := yaml.Marshal([]interface{}{map[string]interface{}{
		"hosts":        "localhost",
		"become":       true,
		"gather_facts": true,
		"roles": []map[string]interface{}{{
			"role": "worker",
			"worker_network": map[string]interface{}{
				"device": 		   device,
				"hostname": 	   hostname,
				"ip_address":      ipAddr,
				"ip_gateway":      ipGateway,
				"ip_netmask":      ipNetmask,
				"ip_v6_address":   ipV6Addr,
				"ip_v6_gateway":   ipV6Gateway,
				"tailscale_token": tailscaleToken,
			},
			"worker_kubernetes": map[string]interface{}{
				"server":           server,
				"kubernetes_token": kubernetesToken,
			},
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

	ansibleCmd := configuration.NewAnsibleWithConfigurationSettingsExecute(
		execute.NewDefaultExecute(
			execute.WithCmd(playbookCmd),
			execute.WithErrorEnrich(playbook.NewAnsiblePlaybookErrorEnrich()),
			execute.WithTransformers(
				transformer.Prepend("worker"),
			),
			execute.WithEnvVars(map[string]string{"PYTHONPATH": f.Python.GetPythonLibFsPath()}),
			execute.WithExecutable(f.Python),
		),
		configuration.WithAnsibleForceColor(),
		configuration.WithAnsibleRolesPath(f.Python.GetRolesFsPath()),
	)

	// Execute the playbook
	err = ansibleCmd.Execute(context.Background())
	if err != nil {
		return fmt.Errorf("failed to execute ansible playbook: %v", err)
	}

	// Print success message
	fmt.Println("\nCompleted successfully!")

	return nil
}
