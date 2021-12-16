# Terratest POC

- [X] service/binary installed
- [X] service enabled/disabled
- [X] user absent
- [X] FIPS enabled
- [X] SELinux enforcing
- [X] HTTP OK
- [X] SSH to public and private hosts

## To do

- [ ] switch cluster VMs Ubuntu -> RHEL
- [ ] use cloud-init
- [X] setup load-balancer to front the cluster
- [ ] implement namespacing (to run parallel tests)
- [ ] better test result output
- [ ] use GitHub actions 

Code heavily inspired by Terratest example code. 

## Usage

To run the Terratest test on the included Terraform code:
1. install the Go programming language (https://go.dev/doc/install)
2. authenthicate: 
    - using az CLI (https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/azure_cli) 
    - or preferably, export the following environment variables containing your Azure service principal's data:
        - `ARM_SUBSCRIPTION_ID="<sub id>"`
        - `ARM_CLIENT_ID="<client id>"`
        - `ARM_TENANT_ID="<tenant id>"`
        - `ARM_CLIENT_SECRET="<secret>"`
3. create a resource group to deploy the test infrastructure and set the resource group Terraform environment variable:
    - e.g. `export TF_VAR_resource_group="RG-Lab-BNguyenDa"`
4. run the Terratest tests: 
    - `cd ./test`
    - `go test -timeout 30m`

When the tests complete, you should see something like this: <br>
<code>PASS<br>
ok  	terratest-poc/test	492.499s</code>

## More info

The Terraform code in this repo creates a simple infrastructure on Azure:
- 1 networks with 2 subnets dubbed 'public' and 'private'
- a RHEL bastion server in the public network (it gets a public IP)
- 2 Ubuntu servers in a 'cluster', these serve a simple 'hello world' webpage (these are in the second private network and have only private IPs)
- a load balancer in front of the 'cluster' VMs

We run the following tests on this infratructure:
- httpTest: check (target: load balancer) for a HTTP 200 response and compare the page served to an expected string
- testSSHToBastion: check that we can SSH into the bastion server and run 'echo' 
- testFIPSOnBastion: check to confirm that FIPS is disabled (we can adapt this to check for the enabled state)
- testSELinuxOnBastion: check that SELinux is enforced on the bastion server
- testUserAbsentOnBastion: make sure that the 'packer' user is absent on the bastion server
- testServiceInstalledOnBastion: make sure a binary is installed on the bastion server
- testSSHToPrivateHost: check that we can SSH into a private 'cluster' server using the bastion as a jump host
- testServiceOnPrivateHost: check if a service is enabled on a private 'cluster' host (bastion jump host used)

Notes: 
- all besides the first test rely on SSH-ing into server either directly or via a jump host
- Terratest deploys the infrastructure, runs the test and finally destroys it, on this infra this may take 300 to 500+ seconds
- it's possible to skip a test stage, e.g. skip the "teardown" stage by setting the environment variable "SKIP_teardown=true"
