package init

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
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
	var email string
	var hostname string
	var ipPool string
	var ipAddr string
	var ipNetmask string
	var ipGateway string
	var ipV6Pool string
	var ipV6Addr string
	var ipV6Gateway string
	var tailscaleToken string

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize a master service.",
		Long:  "Initialize a master service on this machine.",
		Run: func(cmd *cobra.Command, args []string) {
			err := runInit(f, device, email, hostname, ipPool, ipAddr, ipNetmask, ipGateway, ipV6Pool, ipV6Addr, ipV6Gateway, tailscaleToken)
			if err != nil {
				log.Fatalf("init command failed: %v", err)
			}
		},
	}

	// Define flags for network configuration
	cmd.Flags().StringVar(&device, "device", "", "Network interface device name (e.g. 'eth0')")
	cmd.Flags().StringVar(&email, "email", "hostmaster@superclustr.net", "Email address (e.g. 'hostmaster@acme.net')")
	cmd.Flags().StringVar(&hostname, "hostname", "", "Hostname (e.g. 'node01.superclustr.net')")
	cmd.Flags().StringVar(&ipPool, "ip-pool", "", "LoadBalancer IP pool range (e.g., '192.168.1.240/25')")
	cmd.Flags().StringVar(&ipAddr, "ip-address", "", "Static IP address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipNetmask, "ip-netmask", "", "IP netmask (required if ip-address is static)")
	cmd.Flags().StringVar(&ipGateway, "ip-gateway", "", "Gateway IP address (required if ip-address is static)")
	cmd.Flags().StringVar(&ipV6Pool, "ip-v6-pool", "", "LoadBalancer IPv6 pool range (e.g., '2001:678:7ec:70::1/64')")
	cmd.Flags().StringVar(&ipV6Addr, "ip-v6-address", "", "Static IPv6 address or 'dhcp' for dynamic assignment")
	cmd.Flags().StringVar(&ipV6Gateway, "ip-v6-gateway", "", "IPv6 Gateway IP address (required if ip-v6-address is static)")
	cmd.Flags().StringVar(&tailscaleToken, "tailscale-token", "", "Tailscale authentication token (required for vpn network access)")
	return cmd
}

func runInit(f *cli.Factory, device string, email string, hostname string, ipPool string, ipAddr string, ipNetmask string, ipGateway string, ipV6Pool string, ipV6Addr string, ipV6Gateway string, tailscaleToken string) error {
	// Validate inputs
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
			"role": "master",
			"master_network": map[string]interface{}{
				"device": 		   device,
				"hostname": 	   hostname,
				"ip_pool":         ipPool,
				"ip_address":      ipAddr,
				"ip_gateway":      ipGateway,
				"ip_netmask":      ipNetmask,
				"ip_v6_pool":      ipV6Pool,
				"ip_v6_address":   ipV6Addr,
				"ip_v6_gateway":   ipV6Gateway,
				"tailscale_token": tailscaleToken,
			},
			"master_kubernetes": map[string]interface{}{
				"taint": "node-role.kubernetes.io/control-plane:NoSchedule",
				"email": email,
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
				transformer.Prepend("master"),
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
	tokenFile := filepath.Join("/var/lib/rancher/k3s/server/node-token")
	token, err := os.ReadFile(tokenFile)
	if err != nil {
		return fmt.Errorf("failed to read node token file: %v", err)
	}

	// Get the Tailscale IP address
	tailscaleIPCmd := exec.Command("tailscale", "ip", "-4")
	tailscaleIPOutput, err := tailscaleIPCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get Tailscale IP: %v", err)
	}
	tailscaleIP := strings.TrimSpace(string(tailscaleIPOutput))

	fmt.Println("\nTo join a worker node, execute the following command:\n")

	fmt.Printf("curl -sSL https://archive.superclustr.net/super.sh | bash -s worker init \\\n")
	fmt.Printf("    --server %s \\\n", tailscaleIP)
	fmt.Printf("    --tailscale-token %s \\\n", tailscaleToken)
	fmt.Printf("    --kubernetes-token %s\n\n", string(token))

	fmt.Println("Completed successfully!")

	return nil
}
