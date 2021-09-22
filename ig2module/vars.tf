variable "unique_id" {
} # string added to the front for all created resources

# create resources in this vpc id
variable "ibm_is_vpc_id" {
}

variable "vsi-ig-lb" {
}

variable "vsi-ig-lb-id" {
}

variable vsi-ig-lb-pool-id{

}

# create resources in this resource group id
variable "ibm_is_resource_group_id" {
}

variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
  default     = "us-south"
}

variable "az_list" {
  description = "IBM Cloud availability zones"
}

# VSI compute profile for webserver host
variable "profile" {
}

# Id of VSI image 
variable "ibm_is_image_id" {
}

# SSH key for ig2 webservers. 
variable "ibm_is_ssh_key_id" {
}

# webserver instance is put in this subnet
variable "subnet_ids" {
}

# bastion sg requiring access to ig2 security group
variable "bastion_remote_sg_id" {
}

# bastion subnet CIDR requiring access to ig2 subnets 
variable "bastion_subnet_CIDR" {
}

variable "app_ig2_sg_id" {
}

# Allowable CIDRs of public repos from which Ansible can deploy code
variable "pub_repo_egress_cidr" {
}

variable "ig2_count" {
  description = "number of ig1 pool zones"
  default     = 1
}

variable "health_port" {
  description = "Health Port of the VSI"
}

variable "app_port" {
  description = "Port on which application is running."
}