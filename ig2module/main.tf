##############################################################################
# Sample module to deploy a 'ig2 pool' server VSI and security group  
# No NACL is defined. As no floating (public) IPs are defined # Security Group 
# configuration by itself is considered sufficient to protect access to the webserver.
# Subnets are defined in the VPC module. 
##############################################################################

# this is the SG applied to the ig2 instances
resource "ibm_is_security_group" "ig2" {
  name           = "${var.unique_id}-ig2-sg"
  vpc            = var.ibm_is_vpc_id
  resource_group = var.ibm_is_resource_group_id
}


locals {
  sg_keys = ["direction", "remote", "type", "port_min", "port_max"]


  sg_rules = [
    ["inbound", var.bastion_remote_sg_id, "tcp", 22, 22],
    ["outbound", "0.0.0.0/0", "tcp", 443, 443],
    ["outbound", "0.0.0.0/0", "tcp", 80, 80],
    ["outbound", "0.0.0.0/0", "udp", 53, 53],
    ["inbound", "0.0.0.0/0", "tcp", var.health_port, var.health_port],
    ["inbound", "0.0.0.0/0", "tcp", var.app_port, var.app_port]
  ]

  sg_mappedrules = [
    for entry in local.sg_rules :
    merge(zipmap(local.sg_keys, entry))
  ]
}


resource "ibm_is_security_group_rule" "ig2_access" {
  count     = length(local.sg_mappedrules)
  group     = ibm_is_security_group.ig2.id
  direction = (local.sg_mappedrules[count.index]).direction
  remote    = (local.sg_mappedrules[count.index]).remote
  dynamic "tcp" {
    for_each = local.sg_mappedrules[count.index].type == "tcp" ? [
      {
        port_max = local.sg_mappedrules[count.index].port_max
        port_min = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = tcp.value.port_max
      port_min = tcp.value.port_min

    }
  }
  dynamic "udp" {
    for_each = local.sg_mappedrules[count.index].type == "udp" ? [
      {
        port_max = local.sg_mappedrules[count.index].port_max
        port_min = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = udp.value.port_max
      port_min = udp.value.port_min
    }
  }
  dynamic "icmp" {
    for_each = local.sg_mappedrules[count.index].type == "icmp" ? [
      {
        type = local.sg_mappedrules[count.index].port_max
        code = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      type = icmp.value.type
      code = icmp.value.code
    }
  }
}

##############################################################################
# Instance Template and the Instance Group
# 
##############################################################################

data "template_file" "ig2_userdata" {
  template = file("${path.module}/config.yaml")
  vars = {
    app_port = var.app_port
    health_port = var.health_port
  }
}

resource "ibm_is_instance_template" "ig2_instance_template" {
  name           = "${var.unique_id}-ig2-template"
  image          = var.ibm_is_image_id
  profile        = var.profile
  resource_group = var.ibm_is_resource_group_id

  primary_network_interface {
    subnet          = var.subnet_ids[index ( tolist(split(",", var.az_list)) , element(split(",", var.az_list) , 0 ))]
    security_groups = [ibm_is_security_group.ig2.id]
  }

  vpc       = var.ibm_is_vpc_id
  zone      = trimspace(element(split(",", var.az_list) , 0 ))
  keys      = [var.ibm_is_ssh_key_id]
  user_data = data.template_file.ig2_userdata.rendered
}  

resource "ibm_is_instance_group" "ig2_instance_group" {
  name               = "${var.unique_id}-ig2"
  instance_template  = ibm_is_instance_template.ig2_instance_template.id
  instance_count     = var.ig2_count
  subnets            = toset(var.subnet_ids)
  resource_group     = var.ibm_is_resource_group_id
}

data "ibm_is_instance_group_memberships" "is_instance_group_membership-2" {
  instance_group = ibm_is_instance_group.ig2_instance_group.id
}

data "ibm_is_instance" "instances" {
  count          = var.ig2_count
  name = data.ibm_is_instance_group_memberships.is_instance_group_membership-2.memberships[count.index].instance[0].name
}

resource "ibm_is_lb_pool_member" "ig1_lb_mem" {
  count          = var.ig2_count
  lb             = var.vsi-ig-lb-id
  pool           = var.vsi-ig-lb-pool-id
  port           = var.health_port
  target_address = data.ibm_is_instance.instances[count.index].primary_network_interface[0].primary_ipv4_address
  weight         = 0
  depends_on     = [ibm_is_instance_group.ig2_instance_group]
}