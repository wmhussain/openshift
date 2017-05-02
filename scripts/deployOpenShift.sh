#!/bin/bash

set -e

SUDOUSER=$1
PASSWORD="$2"
PRIVATEKEYtmp=$3
PRIVATEKEY="-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAr40HpLCtmcFaAot7XB/BWJ21USHE4HBoF7zLI1eberRSA+0Q
yLE0Fo3sDWVC2RD7pd17IIhUvZWaV7O2y5yIQyhdzYPd2yw1I4V1tfVhSSrTVL7P
QCbGf+08svB88TbW+nlRE+PJxy9I4IDc14dihckZOWySlFY8FTUHigtoBepiYezH
9f2OaaOVRSxdV3QxuIzfvXpW4fQQbaSPVQ6LK4WOq0Hq+jZdAY92T8napsmlHULu
DnS4nM1WyBE0mhfTmvcqRSTMcanRn6PdX/MViu3Zt1ECi2x9NmjZgRU/jSYm5HX0
vOICaHDW1CToDBJ0I1jsM5e8CL7Rhtri8kApQQIDAQABAoIBACk/owcgeHoDQ4oL
ih3YXE7dJ6h7nc36u4qwUq7oO+E2E3tWrbXqZUnTaR6wp2dnpSmRBAhd4EN3rn9i
+9WV3zKgfoH2tR91oLrK9iCeGpDdnjBwcTQqqEOQ081b0o+/Cf5qmRFqWZQS2TXf
MYT3C8BRwzqJ91shdBarkizuhy+0Qm4FJNIGyRCi+m+vKUjfmHQkPBaIOCHPZ4Pu
UWKLkoPXlXJ/oqZ/KM2mPzJOfyK40LldySNKLBtz/ALmsNZwhRY2i0qJ7JrYnP/P
4YvRmzhyNtIYF4r+YtTfB0PGMm2V2d383gDYul1R2boU+MGLUVhKbeKMvwzI9KcZ
s5KLv80CgYEA1po2zOICLuPPx/UBUUG50pENttyp0oGfEKtYpdWrHXK/ftAZAVnk
kGnlkKqWKrsUYmDPnjzDmnXbZnceDTmN4jJVxqtRzAkhNFAuyqaX3vXay9vNFrKu
9VoGyjp614hXmU8YdZ5pbbkdc5kcuIIBbnv6GcdOj+mZqlFyNkIVGBMCgYEA0WpS
XqObbo+VzuXpTEm29U+M2rsBYcfCror9X3ePGZycNp96BVZHAUMLWigsqhC3A/WM
BiNlWoFQaGWE6+BCMyEvRToDjyqWWU8tO6ANJOSdf4fHhbifgoUoJ4i+guM0RUUO
kFSBRZn+NABrTau/FPzwstp+175kBQLdWbYdS9sCgYAXS4IrV1U5Vc1WPUg5U9Mi
AlDkyqs8iImFu7PRvJHojm4vC9PLC8D91CDxRTMrzEb4Lt4apSnueGCqjL+cW+UE
6sXY3PvyFAOgtBuAL/lIYJOxkVh/4EGRrIYUKajwAILRx342Nk3ndTK3O6WcebBC
F/8cEUB76rWdgV3OefnkNQKBgGu0DQ0ThBtGybuRT32m4+wir8THLRzHCn+OiGWT
Lgv0GfuV5cHc78PcYXhK9T26PwZQQWXeyn/TxjELFWPjAOkfBhrKjY4STyU7rX3f
ASOaWM6AXMOPgqo0JcS/dYwHopiFvcnJTHspii3gkU9vJ2V5+ali6p23E+Xn5UQA
f+zFAoGBAI/5AcUI7D2wSLsHmz+3teh3X3NRkEIxsvWM5TeWpWRiOh6wxoiELKoY
YgD6a22jW+J7KbqdEN7LlFTvIJgoqZgmb8yL1FEyvjI0PMR6RLOF9qO76GTcEwaX
SCzd4Pdb6UDHZYPnsvmvMaeG84GLtp+E9D8jzY7izz6QkHA2crvw
-----END RSA PRIVATE KEY-----"

MASTER=$4
MASTERPUBLICIPHOSTNAME=$5
MASTERPUBLICIPADDRESS=$6
NODE=$7
NODECOUNT=$8
ROUTING=$9

NODELOOP=$((NODECOUNT - 1))

DOMAIN=$( awk 'NR==2' /etc/resolv.conf | awk '{ print $2 }' )

# Generate public / private keys for use by Ansible

echo "Generating keys"

sudo runuser -l $SUDOUSER -c "echo \"$PRIVATEKEY\" > ~/.ssh/id_rsa"
sudo runuser -l $SUDOUSER -c "chmod 600 ~/.ssh/id_rsa*"

echo "Configuring SSH ControlPath to use shorter path name"

sudo sed -i -e "s/^# control_path = %(directory)s\/%%h-%%r/control_path = %(directory)s\/%%h-%%r/" /etc/ansible/ansible.cfg
sudo sed -i -e "s/^#host_key_checking = False/host_key_checking = False/" /etc/ansible/ansible.cfg
sudo sed -i -e "s/^#pty=False/pty=False/" /etc/ansible/ansible.cfg

# Create Ansible Hosts File

echo "Generating Ansible hosts file"

sudo cat > /etc/ansible/hosts <<EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=$SUDOUSER
ansible_become=yes
openshift_install_examples=true
deployment_type=origin
openshift_release=v1.4
openshift_image_tag=v1.4.0
docker_udev_workaround=True
openshift_use_dnsmasq=false
openshift_override_hostname_check=true
openshift_master_default_subdomain=$ROUTING

openshift_master_cluster_public_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_vip=$MASTERPUBLICIPADDRESS

# Enable htpasswd auth for username / password authentication
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# host group for masters
[masters]
$MASTER.$DOMAIN

# host group for nodes
[nodes]
$MASTER.$DOMAIN openshift_node_labels="{'region': 'master', 'zone': 'default'}"
$NODE-[0:${NODELOOP}].$DOMAIN openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
EOF

sudo runuser -l $SUDOUSER -c "git clone https://github.com/openshift/openshift-ansible /home/$SUDOUSER/openshift-ansible"

echo "Executing Ansible playbook"

sudo runuser -l $SUDOUSER -c "ansible-playbook openshift-ansible/playbooks/byo/config.yml"

echo "Modifying sudoers"

sudo sed -i -e "s/Defaults    requiretty/# Defaults    requiretty/" /etc/sudoers
sudo sed -i -e '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/aDefaults    env_keep += "PATH"' /etc/sudoers

# Deploy Registry and Router

echo "Deploying Registry"

# runuser -l $SUDOUSER -c "sudo oadm registry"

echo "Deploying Router"

# runuser -l $SUDOUSER -c "sudo oadm router osrouter --replicas=$NODECOUNT --selector=region=infra"

echo "Re-enabling requiretty"

sudo sed -i -e "s/# Defaults    requiretty/Defaults    requiretty/" /etc/sudoers

# Create OpenShift User

echo "Creating OpenShift User"

sudo mkdir -p /etc/origin/master
sudo htpasswd -cb /etc/origin/master/htpasswd ${SUDOUSER} ${PASSWORD}

echo "Script complete"
