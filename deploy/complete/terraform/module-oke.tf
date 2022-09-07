# Copyright (c) 2022, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
# 

module "vault" {
  source = "github.com/oracle-quickstart/oke-base//modules/oci-vault-kms?ref=0.4.0"

  providers = {
    oci             = oci
    oci.home_region = oci.home_region
  }

  # Oracle Cloud Infrastructure Tenancy and Compartment OCID
  tenancy_ocid = var.tenancy_ocid

  # Deployment Tags + Freeform Tags
  freeform_deployment_tags = local.freeform_deployment_tags

  # Encryption (OCI Vault/Key Management/KMS)
  use_encryption_from_oci_vault = var.use_encryption_from_oci_vault
  create_new_encryption_key     = var.create_new_encryption_key
  existent_encryption_key_id    = var.existent_encryption_key_id

  # OKE Cluster Details
  oke_cluster_compartment_ocid = local.oke_compartment_ocid

  ## Create Dynamic group and Policies for OCI Vault (Key Management/KMS)
  create_dynamic_group_for_nodes_in_compartment = var.create_dynamic_group_for_nodes_in_compartment
  create_compartment_policies                   = var.create_compartment_policies
  create_vault_policies_for_group               = var.create_vault_policies_for_group
}

module "oke" {
  source = "github.com/oracle-quickstart/oke-base//modules/oke?ref=0.4.0"

  providers = {
    oci             = oci
    oci.home_region = oci.home_region
  }

  # Oracle Cloud Infrastructure Tenancy and Compartment OCID
  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = local.oke_compartment_ocid
  region           = var.region

  # Deployment Tags + Freeform Tags
  freeform_deployment_tags = local.freeform_deployment_tags

  # OKE Cluster
  ## create_new_oke_cluster
  create_new_oke_cluster  = var.create_new_oke_cluster
  existent_oke_cluster_id = var.existent_oke_cluster_id

  ## Cluster Workers visibility
  cluster_workers_visibility = var.cluster_workers_visibility

  ## Cluster API Endpoint visibility
  cluster_endpoint_visibility = var.cluster_endpoint_visibility

  ## Control Plane Kubernetes Version
  k8s_version = var.k8s_version

  ## Create Dynamic group and Policies for Autoscaler and OCI Metrics and Logging
  create_dynamic_group_for_nodes_in_compartment = var.create_dynamic_group_for_nodes_in_compartment
  create_compartment_policies                   = var.create_compartment_policies

  ## Encryption (OCI Vault/Key Management/KMS)
  oci_vault_key_id_oke_secrets      = module.vault.oci_vault_key_id
  oci_vault_key_id_oke_image_policy = module.vault.oci_vault_key_id
}

module "oke_node_pool" {
  for_each = { for map in local.node_pools : map.node_pool_name => map }
  source   = "github.com/oracle-quickstart/oke-base//modules/oke-node-pool?ref=0.4.0"

  # Deployment Tags + Freeform Tags
  freeform_deployment_tags = local.freeform_deployment_tags

  # Oracle Cloud Infrastructure Tenancy and Compartment OCID
  tenancy_ocid = var.tenancy_ocid

  # OKE Cluster Details
  oke_cluster_ocid             = module.oke.oke_cluster_ocid
  oke_cluster_compartment_ocid = local.oke_compartment_ocid
  create_new_node_pool         = var.create_new_oke_cluster

  # OKE Worker Nodes (Compute)
  node_pool_name                            = each.value.node_pool_name
  node_pool_min_nodes                       = each.value.node_pool_min_nodes
  node_pool_max_nodes                       = each.value.node_pool_max_nodes
  node_k8s_version                          = each.value.node_k8s_version
  node_pool_shape                           = each.value.node_pool_shape
  node_pool_node_shape_config_ocpus         = each.value.node_pool_node_shape_config_ocpus
  node_pool_node_shape_config_memory_in_gbs = each.value.node_pool_node_shape_config_memory_in_gbs
  existent_oke_nodepool_id_for_autoscaler   = each.value.existent_oke_nodepool_id_for_autoscaler
  public_ssh_key                            = local.workers_public_ssh_key
  image_operating_system                    = each.value.image_operating_system
  image_operating_system_version            = each.value.image_operating_system_version

  # OKE Network Details
  oke_vcn_nodes_subnet_ocid = module.oke.oke_vcn_nodes_subnet_ocid

  # Encryption (OCI Vault/Key Management/KMS)
  oci_vault_key_id_oke_node_boot_volume = module.vault.oci_vault_key_id
}
locals {
  node_pools = [
    {
      node_pool_name                            = var.node_pool_name_1 != "" ? var.node_pool_name_1 : "pool1" # Must be unique
      node_pool_min_nodes                       = var.cluster_autoscaler_enabled ? var.cluster_autoscaler_min_nodes_1 : var.num_pool_workers_1
      node_pool_max_nodes                       = var.cluster_autoscaler_max_nodes_1
      node_k8s_version                          = var.k8s_version # TODO: Allow to set different version for each node pool
      node_pool_shape                           = var.node_pool_instance_shape_1.instanceShape
      node_pool_node_shape_config_ocpus         = var.node_pool_instance_shape_1.ocpus
      node_pool_node_shape_config_memory_in_gbs = var.node_pool_instance_shape_1.memory
      node_pool_boot_volume_size_in_gbs         = var.node_pool_boot_volume_size_in_gbs_1
      existent_oke_nodepool_id_for_autoscaler   = var.existent_oke_nodepool_id_for_autoscaler_1
      image_operating_system                    = var.image_operating_system_1
      image_operating_system_version            = var.image_operating_system_version_1
    },
  ]
}

module "oke_cluster_autoscaler" {
  source = "github.com/oracle-quickstart/oke-base//modules/oke-cluster-autoscaler?ref=0.4.0"

  # Oracle Cloud Infrastructure Tenancy and Compartment OCID
  region = var.region

  ## Enable Cluster Autoscaler
  cluster_autoscaler_enabled = var.cluster_autoscaler_enabled
  oke_node_pools             = values(module.oke_node_pool)

  depends_on = [module.oke, module.oke_node_pool]
}

## OKE Cluster Details
variable "app_name" {
  default     = "K8s App"
  description = "Application name. Will be used as prefix to identify resources, such as OKE, VCN, ATP, and others"
}
variable "create_new_oke_cluster" {
  default     = true
  description = "Creates a new OKE cluster, node pool and network resources"
}
variable "existent_oke_cluster_id" {
  default     = ""
  description = "Using existent OKE Cluster. Only the application and services will be provisioned. If select cluster autoscaler feature, you need to get the node pool id and enter when required"
}
variable "create_new_compartment_for_oke" {
  default     = false
  description = "Creates new compartment for OKE Nodes and OCI Services deployed.  NOTE: The creation of the compartment increases the deployment time by at least 3 minutes, and can increase by 15 minutes when destroying"
}
variable "oke_compartment_description" {
  default = "Compartment for OKE, Nodes and Services"
}

## OKE Visibility (Workers and Endpoint)

variable "cluster_workers_visibility" {
  default     = "Private"
  description = "The Kubernetes worker nodes that are created will be hosted in public or private subnet(s)"

  validation {
    condition     = var.cluster_workers_visibility == "Private" || var.cluster_workers_visibility == "Public"
    error_message = "Sorry, but cluster visibility can only be Private or Public."
  }
}

# NOTE: Private Endpoint is only supported when using OCI Resource Manager for deployment.
variable "cluster_endpoint_visibility" {
  default     = "Public"
  description = "The Kubernetes cluster that is created will be hosted on a public subnet with a public IP address auto-assigned or on a private subnet. If Private, additional configuration will be necessary to run kubectl commands"

  validation {
    condition     = var.cluster_endpoint_visibility == "Private" || var.cluster_endpoint_visibility == "Public"
    error_message = "Sorry, but cluster endpoint visibility can only be Private or Public."
  }
}

## OKE Encryption details
variable "use_encryption_from_oci_vault" {
  default     = false
  description = "By default, Oracle manages the keys that encrypts Kubernetes Secrets at Rest in Etcd, but you can choose a key from a vault that you have access to, if you want greater control over the key's lifecycle and how it's used"
}
variable "create_new_encryption_key" {
  default     = false
  description = "Creates new vault and key on OCI Vault/Key Management/KMS and assign to boot volume of the worker nodes"
}
variable "existent_encryption_key_id" {
  default     = ""
  description = "Use an existent master encryption key to encrypt boot volume and object storage bucket. NOTE: If the key resides in a different compartment or in a different tenancy, make sure you have the proper policies to access, or the provision of the worker nodes will fail"
}
variable "create_vault_policies_for_group" {
  default     = false
  description = "Creates policies to allow the user applying the stack to manage vault and keys. If you are on the Administrators group or already have the policies for a compartment, this policy is not needed. If you do not have access to allow the policy, ask your administrator to include it for you"
}
variable "user_admin_group_for_vault_policy" {
  default     = "Administrators"
  description = "User Identity Group to allow manage vault and keys. The user running the Terraform scripts or Applying the ORM Stack need to be on this group"
}

## OKE Autoscaler
variable "cluster_autoscaler_enabled" {
  default     = true
  description = "Enables OKE cluster autoscaler. Node pools will auto scale based on the resources usage"
}
variable "cluster_autoscaler_min_nodes_1" {
  default     = 3
  description = "Minimum number of nodes on the node pool to be scheduled by the Kubernetes (pool1)"
}
variable "cluster_autoscaler_max_nodes_1" {
  default     = 10
  description = "Maximum number of nodes on the node pool to be scheduled by the Kubernetes (pool1)"
}
variable "existent_oke_nodepool_id_for_autoscaler_1" {
  default     = ""
  description = "Nodepool Id of the existent OKE to use with Cluster Autoscaler (pool1)"
}

## OKE Node Pool Details
variable "k8s_version" {
  default     = "Latest"
  description = "Kubernetes version installed on your Control Plane and worker nodes. If not version select, will use the latest available."
}
### Node Pool 1
variable "node_pool_name_1" {
  default     = "pool1"
  description = "Name of the node pool"
}
variable "num_pool_workers_1" {
  default     = 3
  description = "The number of worker nodes in the node pool. If select Cluster Autoscaler, will assume the minimum number of nodes configured"
}

#### ocpus and memory are only used if flex shape is selected
variable "node_pool_instance_shape_1" {
  type = map(any)
  default = {
    "instanceShape" = "VM.Standard.E4.Flex"
    "ocpus"         = 2
    "memory"        = 16
  }
  description = "A shape is a template that determines the number of OCPUs, amount of memory, and other resources allocated to a newly created instance for the Worker Node. Select at least 2 OCPUs and 16GB of memory if using Flex shapes"
}
variable "node_pool_boot_volume_size_in_gbs_1" {
  default     = "60"
  description = "Specify a custom boot volume size (in GB)"
}
variable "image_operating_system_1" {
  default     = "Oracle Linux"
  description = "The OS/image installed on all nodes in the node pool."
}
variable "image_operating_system_version_1" {
  default     = "8"
  description = "The OS/image version installed on all nodes in the node pool."
}
variable "generate_public_ssh_key" {
  default = true
}
variable "public_ssh_key" {
  default     = ""
  description = "In order to access your private nodes with a public SSH key you will need to set up a bastion host (a.k.a. jump box). If using public nodes, bastion is not needed. Left blank to not import keys."
}

# Create Dynamic Group and Policies
variable "create_dynamic_group_for_nodes_in_compartment" {
  default     = true
  description = "Creates dynamic group of Nodes in the compartment. Note: You need to have proper rights on the Tenancy. If you only have rights in a compartment, uncheck and ask you administrator to create the Dynamic Group for you"
}
variable "existent_dynamic_group_for_nodes_in_compartment" {
  default     = ""
  description = "Enter previous created Dynamic Group for the policies"
}
variable "create_compartment_policies" {
  default     = true
  description = "Creates policies that will reside on the compartment. e.g.: Policies to support Cluster Autoscaler, OCI Logging datasource on Grafana"
}

variable "tag_values" {
  type = map(any)
  default = { "freeformTags" = {
    "Environment" = "Development", # e.g.: Demo, Sandbox, Development, QA, Stage, ...
  "DeploymentType" = "generic" } } # e.g.: App Type 1, App Type 2, Red, Purple, ...
  description = "Use Tagging to add metadata to resources. All resources created by this stack will be tagged with the selected tag values."
}

resource "random_string" "deploy_id" {
  length  = 4
  special = false
}

resource "oci_identity_compartment" "oke_compartment" {
  compartment_id = var.compartment_ocid
  name           = "${local.app_name_normalized}-${local.deploy_id}"
  description    = "${var.app_name} ${var.oke_compartment_description} (Deployment ${local.deploy_id})"
  enable_delete  = true

  count = var.create_new_compartment_for_oke ? 1 : 0
}

# Generate ssh keys to access Worker Nodes, if generate_public_ssh_key=true, applies to the pool
resource "tls_private_key" "oke_worker_node_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Locals
locals {
  deploy_id            = random_string.deploy_id.result
  oke_compartment_ocid = var.create_new_compartment_for_oke ? oci_identity_compartment.oke_compartment.0.id : var.compartment_ocid
  deploy_tags = {
    "DeploymentID" = local.deploy_id,
    "AppName"      = var.app_name,
  "Quickstart" = "oke_base" }
  freeform_deployment_tags = merge(var.tag_values.freeformTags, local.deploy_tags)
  workers_public_ssh_key   = var.generate_public_ssh_key ? tls_private_key.oke_worker_node_ssh_key.public_key_openssh : var.public_ssh_key
  app_name_normalized      = substr(replace(lower(var.app_name), " ", "-"), 0, 6)
}

# OKE Outputs

output "comments" {
  value = module.oke.comments
}
output "deploy_id" {
  value = local.deploy_id
}
output "deployed_oke_kubernetes_version" {
  value = module.oke.deployed_oke_kubernetes_version
}
output "deployed_to_region" {
  value = module.oke.deployed_to_region
}
output "kubeconfig" {
  value     = module.oke.kubeconfig
  sensitive = true
}
output "kubeconfig_for_kubectl" {
  value       = module.oke.kubeconfig_for_kubectl
  description = "If using Terraform locally, this command set KUBECONFIG environment variable to run kubectl locally"
}
output "dev" {
  value = module.oke.dev
}
### Important Security Notice ###
# The private key generated by this resource will be stored unencrypted in your Terraform state file. 
# Use of this resource for production deployments is not recommended. 
# Instead, generate a private key file outside of Terraform and distribute it securely to the system where Terraform will be run.
output "generated_private_key_pem" {
  value     = var.generate_public_ssh_key ? tls_private_key.oke_worker_node_ssh_key.private_key_pem : "No Keys Auto Generated"
  sensitive = true
}
