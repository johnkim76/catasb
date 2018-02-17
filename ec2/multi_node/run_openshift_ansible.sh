#!/bin/sh
[ -z "$AWS_ACCESS_KEY_ID" ] && echo -e "Missing environment variable:  AWS_ACCESS_KEY_ID" && exit 1;
[ -z "$AWS_SECRET_ACCESS_KEY" ] && echo -e "Missing environment variable:  AWS_SECRET_ACCESS_KEY" && exit 1;
[ -z "$AWS_SSH_PRIV_KEY_PATH" ] && echo -e "Missing environment variable:  AWS_SSH_PRIV_KEY_PATH\nPlease set this to the path for your SSH private key" && exit 1;
[ ! -r "$AWS_SSH_PRIV_KEY_PATH" ] && echo -e "Unable to read file pointed to by, AWS_SSH_PRIV_KEY_PATH, $AWS_SSH_PRIV_KEY_PATH" && exit 1;

EC2_TYPE="multi_node"

source ../../gather_config

# preinstallation checks
ansible-playbook \
  ${ANS_CODE}/openshift_ansible_preinstall_checks.yml \
  --extra-vars "${EXTRA_VARS}" \
  ${extra_args} $@
if [ $? -eq 0 ]; then
  echo -e "OpenShift Ansible preinstallation check - Success!\n\n"
else
  echo -e "ERROR: Something went wrong during preinstallation check! exiting... \n"
  exit -1
fi

#
# Get and set the INVENTORY_FILE path
#
# /tmp/aos_inventory_path_info.txt contains the PATH of the inventory file
# for the 'openshift-ansible' BYO playbook
#
# Note: this path is also set in global_vars/all.yml
# INVENTORY_FILE        - 'openshift_ansible_inventory_info_file'
# OPENSHIFT_ANSIBLE_DIR - 'openshift_ansible_repo_dir'
#
INVENTORY_FILE=`more /tmp/aos_inventory_path_info.txt`
OPENSHIFT_ANSIBLE_DIR="/tmp/openshift-ansible"

# Run the OpenShift Ansible prerequisites playbook
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook \
  -i ${INVENTORY_FILE} \
  ${OPENSHIFT_ANSIBLE_DIR}/playbooks/prerequisites.yml
if [ $? -eq 0 ]; then
  echo -e "OpenShift Ansible playbooks/prerequisites.yml - Success!\n\n"
else
  echo -e "ERROR: Something went wrong during playbooks/prerequisites.yml! exiting... \n"
  exit -1
fi

# Run the OpenShift Ansible deploy_cluster playbook
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook \
  -i ${INVENTORY_FILE} \
  ${OPENSHIFT_ANSIBLE_DIR}/playbooks/deploy_cluster.yml
