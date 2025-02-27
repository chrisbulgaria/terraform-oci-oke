# Copyright 2017, 2021 Oracle Corporation and/or affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_containerengine_cluster_kube_config" "kube_config" {
  cluster_id = var.cluster_id
}

resource "local_file" "kube_config_file" {
  content         = data.oci_containerengine_cluster_kube_config.kube_config.content
  filename        = "${path.root}/generated/kubeconfig"
  file_permission = "0600"
}

resource "null_resource" "write_kubeconfig_on_operator" {
  connection {
    host        = var.operator_private_ip
    private_key = local.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"

    bastion_host        = var.bastion_public_ip
    bastion_user        = "opc"
    bastion_private_key = local.ssh_private_key
  }

  depends_on = [null_resource.install_k8stools_on_operator]

  provisioner "file" {
    content     = local.generate_kubeconfig_template
    destination = "/home/opc/generate_kubeconfig.sh"
  }

  provisioner "file" {
    content     = local.token_helper_template
    destination = "/home/opc/token_helper.sh"
  }

  provisioner "file" {
    content     = local.set_credentials_template
    destination = "/home/opc/kubeconfig_set_credentials.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "if [ -f \"$HOME/generate_kubeconfig.sh\" ]; then bash \"$HOME/generate_kubeconfig.sh\"; rm -f \"$HOME/generate_kubeconfig.sh\";fi",
      "mkdir $HOME/bin",
      "chmod +x $HOME/token_helper.sh",
      "mv $HOME/token_helper.sh $HOME/bin",
      "if [ -f \"$HOME/kubeconfig_set_credentials.sh\" ]; then bash \"$HOME/kubeconfig_set_credentials.sh\"; rm -f \"$HOME/kubeconfig_set_credentials.sh\";fi",
    ]
  }

  count = local.post_provisioning_ops == true ? 1 : 0
}
