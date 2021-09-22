
# provider block required with Schematics to set VPC region
provider "ibm" {
  region = var.ibm_region
  #ibmcloud_api_key = var.ibmcloud_api_key
  generation = local.generation
  version    = "~> 1.4"
}

data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

locals {
  generation = 2
  ig1_count = var.instance_count
  ig2_count  = var.instance_count
}


##################################################################################################
#  Select CIDRs allowed to access bastion host  
#  When running under Terraform local execution ingress is set to 0.0.0.0/0
##################################################################################################


data "external" "env" { program = ["jq", "-n", "env"] }
locals {
  region = lookup(data.external.env.result, "TF_VAR_SCHEMATICSLOCATION", "")
  geo    = substr(local.region, 0, 2)
  bastion_ingress_cidr  = ["0.0.0.0/0"]
}


module "vpc" {
  source               = "./vpc"
  ibm_region           = var.ibm_region
  resource_group_name  = var.resource_group_name
  generation           = local.generation
  unique_id            = var.vpc_name
  ig1_count       = local.ig1_count
  ig1_cidr_blocks = local.ig1_cidr_blocks
  ig2_count        = local.ig2_count
  ig2_cidr_blocks  = local.ig2_cidr_blocks
  az_list            = var.az_list
}

locals {
  # bastion_cidr_blocks  = [cidrsubnet(var.bastion_cidr, 4, 0), cidrsubnet(var.bastion_cidr, 4, 2), cidrsubnet(var.bastion_cidr, 4, 4)]
  ig1_cidr_blocks = [cidrsubnet(var.ig1_cidr, 4, 0), cidrsubnet(var.ig1_cidr, 4, 2), cidrsubnet(var.ig1_cidr, 4, 4)]
  ig2_cidr_blocks  = [cidrsubnet(var.ig2_cidr, 4, 0), cidrsubnet(var.ig2_cidr, 4, 2), cidrsubnet(var.ig2_cidr, 4, 4)]
}


# Create single zone bastion
module "bastion" {
  source                   = "./bastionmodule"
  ibm_region               = var.ibm_region
  bastion_count            = 1
  unique_id                = var.vpc_name
  ibm_is_vpc_id            = module.vpc.vpc_id
  ibm_is_image_id          = data.ibm_is_image.os.id
  ibm_is_resource_group_id = data.ibm_resource_group.all_rg.id
  bastion_cidr             = var.bastion_cidr
  ssh_source_cidr_blocks   = local.bastion_ingress_cidr
  destination_cidr_blocks  = [var.ig1_cidr, var.ig2_cidr]
  destination_sgs          = [module.ig1.security_group_id, module.ig2.security_group_id]
  # destination_sg          = [module.ig1.security_group_id, module.ig2.security_group_id]
  # vsi_profile             = "cx2-2x4"
  # image_name              = "ibm-centos-8-3-minimal-amd64-3"
  ssh_key_id = data.ibm_is_ssh_key.sshkey.id
  az_list                   = var.az_list
}


module "ig1" {
  source                   = "./ig1module"
  ibm_region               = var.ibm_region
  unique_id                = var.vpc_name
  ibm_is_vpc_id            = module.vpc.vpc_id
  ibm_is_resource_group_id = data.ibm_resource_group.all_rg.id
  ig1_count               = local.ig1_count
  profile                  = var.profile
  ibm_is_image_id          = data.ibm_is_image.os.id
  ibm_is_ssh_key_id        = data.ibm_is_ssh_key.sshkey.id
  subnet_ids               = module.vpc.ig1_subnet_ids
  bastion_remote_sg_id     = module.bastion.security_group_id
  bastion_subnet_CIDR      = var.bastion_cidr
  pub_repo_egress_cidr     = local.pub_repo_egress_cidr
  app_ig1_sg_id           = module.ig1.security_group_id
  az_list                   = var.az_list
  health_port               = var.health_port
  app_port                  = var.app_port
}

module "ig2" {
  source                   = "./ig2module"
  ibm_region               = var.ibm_region
  unique_id                = var.vpc_name
  ibm_is_vpc_id            = module.vpc.vpc_id
  ibm_is_resource_group_id = data.ibm_resource_group.all_rg.id
  ig2_count            = local.ig2_count
  profile                  = var.profile
  ibm_is_image_id          = data.ibm_is_image.os.id
  ibm_is_ssh_key_id        = data.ibm_is_ssh_key.sshkey.id
  subnet_ids               = module.vpc.ig2_subnet_ids
  bastion_remote_sg_id     = module.bastion.security_group_id
  bastion_subnet_CIDR      = var.bastion_cidr
  app_ig2_sg_id            = module.ig2.security_group_id
  pub_repo_egress_cidr     = local.pub_repo_egress_cidr
  vsi-ig-lb                = module.ig1.lb_hostname
  vsi-ig-lb-id             = module.ig1.lb_id
  vsi-ig-lb-pool-id        = module.ig1.lb_pool_id
  az_list                  = var.az_list
  health_port              = var.health_port
  app_port                 = var.app_port
}
