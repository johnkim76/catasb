# Multi-Node AWS OpenShift Deployment

OpenShift environment with the Service Catalog & Ansible Service Broker configured in AWS with multiple EC2 instances

## Overview

The playbooks will:

* Create a public VPC if it does not exist
* Create a security group if it does not exist
* Create a configurable number of instances with a specific Name if does not exist
* Configure a hostname with as a CNAME record through Route53
* Install OpenShift via [openShift-ansible](https://github.com/openshift/openshift-ansible) with
  * Service Catalog
  * Ansible Service Broker
* Configure cluster users with htpasswd authentication

## Pre-Reqs

* Ansible needs to be installed so its source code is available to Python.
  * Check to see if Ansible modules are available to Python
    ```bash
    $ python -c "import ansible;print(ansible.__version__)"
    2.3.0.0
    ```
  * MacOS requires Ansible to be installed from `pip` and not `brew`
    ```bash
    $ python -c "import ansible;print(ansible.__version__)"
    Traceback (most recent call last):
    File "<string>", line 1, in <module>
    ImportError: No module named ansible

    brew uninstall ansible
    pip install ansible

    $ python -c "import ansible;print(ansible.__version__)"
    2.3.0.0
    ```
* Install python dependencies (This is needed for python2. Use pip3 if using python3)
  * On Fedora and EL7 it is recommended that you use ansible in a python virtualenv.
    * This is due to a couple reasons:
      * boto rpms are not sufficiently new enough
      * pip is not sudo safe on Fedora and EL7
    * To setup and activate a virtualenv do the following;
      ```bash
      sudo dnf install python-virtualenv #or EL7: sudo yum install python-virtualenv
      virtualenv /tmp/ansible
      source /tmp/ansible/bin/activate
      pip install ansible
      ```
  * Continue with the next step:
    ```bash
    pip install boto boto3 six
    ```
* Configure a SSH Key in your AWS EC-2 account for the given region
* Create a hosted zone in Route53
* Set these environment variables:
  ```bash
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_SSH_PRIV_KEY_PATH  - Path to your private ssh key to use for the ec2 instances
  ```

## Quick Start - Scenario Configuration & Execution

The following will describe the *quick start* steps to configure various supported scenarios. All variables shown below needs to be in the `my_vars.yml` file, located in the [`config`](../../config) folder

### AWS Custom Prefix

The default value for the `aws_custom_prefix` is the value of '`whoami`'.  However, if you want to deploy multiple clusters with different configurations, you may separate the AWS resources with a specific tag via specifying the `aws_custom_prefix` as shown below in ADDITION to the configuration changes above

```bash
aws_custom_prefix: jdoe
```

### OCP - Official CDN Repositories

Deploying OCP in RHEL is the default configuration.  However, you MUST provide the RHN credentials and the pool ID with OpenShift Container Platform subscription

```bash
rhn_user:    <rhn_username>
rhn_passwd:  <password>
aos_pool_id: <OpenShift Container Platform subscription pool ID></OpenShift>
```

### Origin

To deploy Origin in RHEL (default OS), set the following

```bash
deploy_origin: true
```

To deploy Origin in CentOS, set the following

```bash
deploy_origin: true
use_centos:    true
centos_ami_id: <aws-centos-ami-id-in-your-region>
```

### Deploy

After making all of the configuration changes above run the following to create your cluster (approx ~25min)

```bash
./create_cluster.sh
```

## Configuration

### 'my_vars.yml' file

All configurable variables are contained in the [`all.yml`](../../ansible/group_vars/all.yml) under the [`group_vars`](../../ansible/group_vars/) folder. Any of these may be *overwritten*, if they're specified differently in the *`my_vars.yml`* file.

### Default Configuration

The default configuration will install OpenShift Container Platform v3.7 from the RH CDN Repository with 1 master, and 2 nodes.

### Number of OSE Nodes

The number of OSE nodes can be specified by the `num_ose_nodes` variable in the `my_vars.yml` file. You may specify 2 or more nodes, but only 1 `master` node is supported at this time.

### Example 'my_vars.yml'

Review the example [`my_vars.yml.example`](../../config/my_vars.yml.example) file, and make a copy of it as `my_vars.yml` in the same [location](../../config).  The following are some of the example values that you may want to have in your `my_vars.yml`

* Specify the `aws_custom_prefix`

  The `aws_custom_prefix` is the string that names and tags all your AWS resources related to the cluster, and keeps them unique within a AWS user account.  Default value is your `$USERNAME`. However, ff you whish to deploy multiple cluster setups, changing the `aws_custom_prefix` will allow you to create multiple cluster deployments, each with its own unique set of names.
  ```bash
  aws_custom_prefix: my_cluster1 # mycluster2, mycluster3, ... etc.
  ```
* RHN Credentials
  ```bash
  enable_rh_cdn_repo: true
  rhn_user:    <rhn_username>
  rhn_passwd:  <password>
  aos_pool_id: <OpenShift Container Platform subscription pool ID>
  ```

## Execute

### Make Configuration Changes

* Navigate to the [`config`](../../config) folder
  ```bash
  cd catasb/config
  ```
* Edit the variables file [`ec2_env_vars`](../../config/ec2_env_vars)
  * Note the following and update:
    ```bash
    AWS_SSH_KEY_NAME="splice"
    TARGET_DNS_ZONE="ec2.dog8code.com"
    ```
    Needs to match a hosted zone entry in your Route53 account, we will create a subdomain under it for the ec2 instance
* create a `my_vars.yml` as described [above](#configuration)

### Create your Cluster

#### Single Step

After making all the desired configuration changes, you can create your cluster all in one step by running the following script.

```bash
./create_cluster.sh
```

#### Multiple Steps

The [`create_cluster.sh`](create_cluster.sh) script runs several scripts in order.  However, you may run those scripts one at a time if so desired.

First, create the AWS infrastructure

```bash
./run_create_infrastructure.sh
```

This script will do the following:

* setup the network
* create EC-2 instances and enable the correct repos
* install required packages
* create inventory file for the [openshift-ansible](https://github.com/openshift/openshift-ansible) installer

At this time, you can modify the auto generated inventory file to suite your needs.  The inventory file is located in the [ansible](../../ansible) folder, and is named `my_aos_inventory_file_<aws_custom_prefix>`

Next, you can run the openshift-ansible installer

```bash
./run_openshift_ansible.sh
```

This script will do the following:

* check if the inventory file exists
* check if the instances exist (to run the playbook on)
* clone the openshift-ansible repo to `/tmp/openshift-ansible`
* run the playbooks [`prerequisites.yml`](https://github.com/openshift/openshift-ansible/blob/master/playbooks/prerequisites.yml) and [`deploy_cluster.yml`](https://github.com/openshift/openshift-ansible/blob/master/playbooks/deploy_cluster.yml)

When this script finishes, your cluster is up and operational, but we'll need to add some users

To add users, run the followings

```bash
./run_post_aos_install.sh
```

This script will do the following

* create an admin user called '`admin`' with password '`admin`'
* create an dev user called '`dev`' with password '`dev`'

If you wish to change the names and/or the password of the users listed above, edit the `my_vars.yml` file, and change the values as desired

```bash
cluster_privileged_user: admin
cluster_privileged_user_password: admin
cluster_dev_user: dev
cluster_dev_user_password: dev
```

## Cluster WebUI

Open a Web Browser and visit the following URL's:

* Visit: `https://master.<AWS_CUSTOM_PREFIX>.ec2.dog8code.com:8443`
  * Accept the SSL certificate for the apiserver-service-catalog endpoint
  * Note: must accept the new SSL cert, each time you create your OpenShift environment
* Visit: `https://<USERNAME>.ec2.dog8code.com:8443`
  * Where `<USERNAME>` is the value of `whoami` when you launched `run_setup_environment.sh`

## Display AWS Information

To display information about the AWS resources and instances in the current configuration run the following:

```bash
./display_information.sh
```

## Cleanup

To destroy your cluster, and to terminate the ec2 instance and cleanup the associated EBS volumes run the below

```bash
 ./terminate_instances.sh
```

## Tested with

* ansible 2.3.0.0
  * Problems were seen using ansible 2.2 and lower
  * Multiple EC-2 Instances
  * Installs [OpenShift Container Platform](https://www.openshift.com/container-platform/index.html) or [Origin](https://www.openshift.org/) via [OpenShift Ansible](https://github.com/openshift/openshift-ansible)
  * Configurable Contents
    * RH CDN
    * Latest Mirror Repos
