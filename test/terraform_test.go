package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	// "github.com/gruntwork-io/terratest/modules/random"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// Skip stage "teardown" by setting the environment variable "SKIP_teardown=true"
func TestTerraform(t *testing.T) {
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")

	// This is the last test to run, clean up after it
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testDir)
		terraform.Destroy(t, terraformOptions)
	})

	// Deploy & save some data for later stages
	test_structure.RunTestStage(t, "setup", func() {
		keyPair := ssh.GenerateRSAKeyPair(t, 4096)
		terraformOptions := &terraform.Options{
			TerraformDir: "../",
			Vars: map[string]interface{}{
				"ssh_public_key": keyPair.PublicKey,
				"resource_group": os.Getenv("TF_VAR_resource_group"),
			},
		}
		// Save the options and key pair so later test stages can use them
		test_structure.SaveTerraformOptions(t, testDir, terraformOptions)
		test_structure.SaveSshKeyPair(t, testDir, keyPair)

		// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
		terraform.InitAndApply(t, terraformOptions)
	})

	// Run tests
	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testDir)
		keyPair := test_structure.LoadSshKeyPair(t, testDir)
		username := "belannd"
		httpTest(t, terraformOptions)
		testSSHToBastion(t, terraformOptions, keyPair, username)
		testFIPSOnBastion(t, terraformOptions, keyPair, username)
		testSELinuxOnBastion(t, terraformOptions, keyPair, username)
		testUserAbsentOnBastion(t, terraformOptions, keyPair, username)
		testServiceInstalledOnBastion(t, terraformOptions, keyPair, username, "ssh")
		testSSHToPrivateHost(t, terraformOptions, keyPair, username)
		testServiceOnPrivateHost(t, terraformOptions, keyPair, username, "nginx")
	})

}

func httpTest(t *testing.T, terraformOptions *terraform.Options) {
	// Get the load balancer FQDN from Terraform output
	url := fmt.Sprintf("http://%s:80", terraform.Output(t, terraformOptions, "load_balancer-fqdn"))

	// the LB might not respond right away
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second

	// HTTP check and string comparison
	http_helper.HttpGetWithRetryWithCustomValidationE(t, url, nil, maxRetries, timeBetweenRetries, func(status int, content string) bool {
		return status == 200 &&
			strings.Contains(content, "hello world from")
	})
}

func testSSHToBastion(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")

	// We're going to try to SSH to the instance IP, using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	// Run a simple echo command on the server
	expectedText := "Hello, World"
	command := fmt.Sprintf("echo -n '%s'", expectedText)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testFIPSOnBastion(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")

	// We're going to try to SSH to the instance IP, using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	// Check FIPS, here we check to confirm it is disabled, on real
	// infrastructure we should check for "crypto.fips_enabled = 1" instead
	expectedText := "crypto.fips_enabled = 0"
	command := "/usr/sbin/sysctl crypto.fips_enabled"

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testSELinuxOnBastion(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")

	// We're going to try to SSH to the instance IP, using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 10
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	// Check the ouput of 'getenforce'
	expectedText := "Enforcing"
	command := "/usr/sbin/getenforce"

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testSSHToPrivateHost(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")
	privateInstanceIP := terraform.OutputList(t, terraformOptions, "cluster-private_ip")[0]

	// We're going to try to SSH to the private instance using the public instance as a jump host. For both instances,
	// we are using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}
	privateHost := ssh.Host{
		Hostname:    privateInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to private host %s via public host %s", privateInstanceIP, publicInstanceIP)

	// Run a simple echo command on the server
	expectedText := "Hello, World"
	command := fmt.Sprintf("echo -n '%s'", expectedText)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckPrivateSshConnectionE(t, publicHost, privateHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testServiceOnPrivateHost(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string, service string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")
	privateInstanceIP := terraform.OutputList(t, terraformOptions, "cluster-private_ip")[0]

	// We're going to try to SSH to the private instance using the public instance as a jump host. For both instances,
	// we are using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}
	privateHost := ssh.Host{
		Hostname:    privateInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to private host %s via public host %s", privateInstanceIP, publicInstanceIP)

	// Check if service is enabled
	expectedText := "enabled"
	command := fmt.Sprintf("systemctl is-enabled %s", service)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckPrivateSshConnectionE(t, publicHost, privateHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testUserAbsentOnBastion(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")

	// We're going to try to SSH to the instance IP, using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// Retry a few times
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	// Check the ouput of 'id'
	expectedText := "/usr/bin/id: packer: no such user"
	command := "/usr/bin/id -u packer"

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err == nil { // Note, here we expect an error
			return "", fmt.Errorf("Expected SSH command to return an error but got none")
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}

func testServiceInstalledOnBastion(t *testing.T, terraformOptions *terraform.Options, keyPair *ssh.KeyPair, username string, service string) {
	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := terraform.Output(t, terraformOptions, "bastion-public_ip")

	// We're going to try to SSH to the instance IP, using the Key Pair we created earlier
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: username,
	}

	// Retry a few times
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	// POSIX friendly way to check if binary exists
	command := fmt.Sprintf("command -v %s", service)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		_, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			return "", err
		}

		return "", nil
	})
}
