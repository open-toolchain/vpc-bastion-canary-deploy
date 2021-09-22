
output security_group_id {
  value = ibm_is_security_group.ig1.id
}

output lb_hostname {
  value = ibm_is_lb.vsi-ig-lb.hostname
}

output lb_id {
  value = ibm_is_lb.vsi-ig-lb.id
}

output lb_pool_id {
  value = ibm_is_lb_pool.vsi-ig-lb-pool.id
}

output "ig_members" {
  value = data.ibm_is_instance_group_memberships.is_instance_group_memberships.memberships[*].instance[*].virtual_server_instance
}