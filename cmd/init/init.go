package init

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
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
	var advertiseAddr string

	cmd := &cobra.Command{
		Use:   "init",
		Short: "init --advertise-addr <ip|interface>[:port]",
		Long:  "Initialize a manager node.",
		Run: func(cmd *cobra.Command, args []string) {
			err := runInit(f, advertiseAddr)
			if err != nil {
				log.Fatalf("init command failed: %v", err)
			}
		},
	}

	cmd.Flags().StringVarP(&advertiseAddr, "advertise-addr", "a", "", "Advertised address")
	return cmd
}

func runInit(f *cli.Factory, advertiseAddr string) error {
	// Build playbook structure
	yamlData, err := yaml.Marshal([]interface{}{map[string]interface{}{
		"hosts":        "localhost",
		"become":       true,
		"gather_facts": true,
		"roles": []map[string]interface{}{{
			"role": "manager",
			"manager_docker": map[string]interface{}{
				"advertise_addr": advertiseAddr,
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
				transformer.Prepend("manager"),
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

	// Get the Docker Swarm join token
	dockerSwarmJoinTokenCmd := exec.Command("docker", "swarm", "join-token", "worker")
	dockerSwarmJoinTokenOutput, err := dockerSwarmJoinTokenCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get Docker Swarm join token: %v", err)
	}
	
	// Extract the token using regex
	outputStr := string(dockerSwarmJoinTokenOutput)
	tokenRegex := regexp.MustCompile(`SWMTKN-\S+`)
	tokenMatches := tokenRegex.FindString(outputStr)
	if tokenMatches == "" {
		return fmt.Errorf("could not find token in docker swarm join-token output")
	}
	dockerSwarmJoinToken := tokenMatches
	
	// Extract the IP:port using regex
	ipRegex := regexp.MustCompile(`(\d+\.\d+\.\d+\.\d+:\d+)`)
	ipMatches := ipRegex.FindStringSubmatch(outputStr)
	if len(ipMatches) < 2 {
		return fmt.Errorf("could not find IP:port in docker swarm join-token output")
	}
	ipAddress := ipMatches[1]

	fmt.Println("\nTo add a worker to this cluster, run the following command:\n")

	fmt.Printf("curl -sSL https://downloads.superclustr.net/super.sh | bash -s join \\\n")
	fmt.Printf("    --token %s \\\n", dockerSwarmJoinToken)
	fmt.Printf("    %s\n\n", ipAddress)

	fmt.Println("Completed successfully!\n")

	return nil
}
