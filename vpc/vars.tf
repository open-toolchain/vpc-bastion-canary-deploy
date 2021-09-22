##############################################################################
# VPC Variables
##############################################################################

variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
}

variable "resource_group_name" {
  description = "ID for IBM Cloud Resource Group"
}

variable "az_list" {
  description = "IBM Cloud availability zones"
}

variable "generation" {
  description = "VPC generation"
  default     = 2
}

# unique vpc name
variable "unique_id" {
  description = "The vpc unique id"
}


variable "ig1_count" {
  description = "number of ig1 pool zones"
  default     = 1
}

variable "ig2_count" {
  description = "number of ig2 pool zones"
  default     = 1
}

##############################################################################
# Network variables
##############################################################################

variable "ig1_cidr_blocks" {
}

variable "ig2_cidr_blocks" {
}
##############################################################################



