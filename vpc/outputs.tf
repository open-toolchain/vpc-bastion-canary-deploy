output "vpc_id" {
  value = ibm_is_vpc.vpc.id
}

output "ig1_subnet_ids" {
  value = ibm_is_subnet.ig1_subnet.*.id
}

output "ig2_subnet_ids" {
  value = ibm_is_subnet.ig2_subnet.*.id
}
