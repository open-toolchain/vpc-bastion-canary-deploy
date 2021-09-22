##############################################################################
# Sample module to deploy a 'ig1' webserver VSI and security group  
# No NACL is defined. As no floating (public) IPs are defined # Security Group 
# configuration by itself is considered sufficient to protect access to the webserver.
# Subnets are defined in the VPC module. 
#
# Redhat Ansible usage is enabled by the addition of VSI tags. All Ansible related VSI 
# tags are prefixed with "ans_group:" followed by the group name.   '
# tags = ["ans_group:ig2"]'  
# Correct specification of tags is essential for operation of the Ansible dynamic inventory
# script used to pass host information to Ansible. The tags here should match the roles
# defined in the site.yml playbook file. 
##############################################################################

# this is the SG applied to the ig1 instances
resource "ibm_is_security_group" "ig1" {
  name           = "${var.unique_id}-ig1-sg"
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


resource "ibm_is_security_group_rule" "ig1_access" {
  count     = length(local.sg_mappedrules)
  group     = ibm_is_security_group.ig1.id
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
# Public load balancer
# 
##############################################################################
# this is the SG applied to the alb
resource "ibm_is_security_group" "alb" {
  name           = "${var.unique_id}-alb-sg"
  vpc            = var.ibm_is_vpc_id
  resource_group = var.ibm_is_resource_group_id
}


locals {
  alb_sg_keys = ["direction", "remote", "type", "port_min", "port_max"]


  alb_sg_rules = [
    ["inbound", "0.0.0.0/0", "all", 1, 65535],
    ["outbound", "0.0.0.0/0", "all", 1, 65535]
  ]

  alb_sg_mappedrules = [
    for entry in local.alb_sg_rules :
    merge(zipmap(local.alb_sg_keys, entry))
  ]
}


resource "ibm_is_security_group_rule" "alb_access" {
  count     = length(local.alb_sg_mappedrules)
  group     = ibm_is_security_group.alb.id
  direction = (local.alb_sg_mappedrules[count.index]).direction
  remote    = (local.alb_sg_mappedrules[count.index]).remote
  dynamic "tcp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "tcp" ? [
      {
        port_max = local.alb_sg_mappedrules[count.index].port_max
        port_min = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = tcp.value.port_max
      port_min = tcp.value.port_min

    }
  }
  dynamic "udp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "udp" ? [
      {
        port_max = local.alb_sg_mappedrules[count.index].port_max
        port_min = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = udp.value.port_max
      port_min = udp.value.port_min
    }
  }
  dynamic "icmp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "icmp" ? [
      {
        type = local.alb_sg_mappedrules[count.index].port_max
        code = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      type = icmp.value.type
      code = icmp.value.code
    }
  }
}

resource "ibm_is_lb" "vsi-ig-lb" {
  name           = "${var.unique_id}-alb"
  type           = "public"
  subnets        = toset(var.subnet_ids)
  security_groups = [ibm_is_security_group.alb.id]
  resource_group = var.ibm_is_resource_group_id

  timeouts {
    create = "15m"
    delete = "15m"
  }


}

resource "ibm_is_lb_pool" "vsi-ig-lb-pool" {
  lb                 = ibm_is_lb.vsi-ig-lb.id
  name               = "canary-lb-pool"
  protocol           = "http"
  algorithm          = "weighted_round_robin"
  health_delay       = "5"
  health_retries     = "2"
  health_timeout     = "2"
  health_type        = "http"
  health_monitor_url = "/"
  depends_on         = [ibm_is_lb.vsi-ig-lb]
}

resource "ibm_is_lb_listener" "vsi-ig-lb-listener" {
  lb           = ibm_is_lb.vsi-ig-lb.id
  port         = var.app_port
  protocol     = "http"
  default_pool = element(split("/", ibm_is_lb_pool.vsi-ig-lb-pool.id), 1)
  depends_on   = [ibm_is_lb_pool.vsi-ig-lb-pool]
}

##############################################################################
# Instance Template and the Instance Group
# 
##############################################################################

data "template_file" "ig1_userdata" {
  template = file("${path.module}/config.yaml")
  vars = {
    app_port = var.app_port
    health_port = var.health_port
  }
}

resource "ibm_is_instance_template" "ig1_template" {
  name           = "${var.unique_id}-ig1-template"
  image          = var.ibm_is_image_id
  profile        = var.profile
  resource_group = var.ibm_is_resource_group_id

  primary_network_interface {
    subnet          = var.subnet_ids[index ( tolist(split(",", var.az_list)) , element(split(",", var.az_list) , 0 ))]
    security_groups = [ibm_is_security_group.ig1.id]
  }

  vpc       = var.ibm_is_vpc_id
  zone      = trimspace(element(split(",", var.az_list) , 0 ))
  keys      = [var.ibm_is_ssh_key_id]
  user_data = data.template_file.ig1_userdata.rendered
}  

resource "ibm_is_instance_group" "ig1_instance_group" {
  name               = "${var.unique_id}-ig1"
  instance_template  = ibm_is_instance_template.ig1_template.id
  instance_count     = var.ig1_count
  subnets            = toset(var.subnet_ids)
  resource_group     = var.ibm_is_resource_group_id
}
data "ibm_is_instance_group_memberships" "is_instance_group_memberships" {
  instance_group = ibm_is_instance_group.ig1_instance_group.id
}

data "ibm_is_instance" "instances-1" {
  count          = var.ig1_count
  name = data.ibm_is_instance_group_memberships.is_instance_group_memberships.memberships[count.index].instance[0].name
}

resource "ibm_is_lb_pool_member" "ig1_lb_mem" {
  count          = var.ig1_count
  lb             = ibm_is_lb.vsi-ig-lb.id
  pool           = ibm_is_lb_pool.vsi-ig-lb-pool.id
  port           = var.health_port
  target_address     = data.ibm_is_instance.instances-1[count.index].primary_network_interface[0].primary_ipv4_address
  weight         = 100
  depends_on     = [ibm_is_instance_group.ig1_instance_group]
}