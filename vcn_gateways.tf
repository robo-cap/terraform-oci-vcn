# Copyright (c) 2019, 2021, Oracle Corporation and/or affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

########################
# Internet Gateway (IGW)
########################

resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "none" ? var.internet_gateway_display_name : "${var.label_prefix}-${var.internet_gateway_display_name}"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  vcn_id = oci_core_vcn.vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_internet_gateway == true ? 1 : 0
}

resource "oci_core_route_table" "ig" {
  compartment_id = var.compartment_id
  display_name   = local.internet_gateway_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  route_rules {
    # * With this route table, Internet Gateway is always declared as the default gateway
    destination       = local.anywhere
    network_entity_id = oci_core_internet_gateway.ig[0].id
    description       = "Terraformed - Auto-generated at Internet Gateway creation: Internet Gateway as default gateway"
  }

  dynamic "route_rules" {
    # * With this route table, Internet Gateway is always declared as the default gateway
    for_each = var.enable_ipv6 == true ? [1] : []

    content {
      destination       = local.anywhere_ipv6
      network_entity_id = oci_core_internet_gateway.ig[0].id
      description       = "Terraformed - Auto-generated at Internet Gateway creation: Internet Gateway as default gateway"
    }
  }

  dynamic "route_rules" {
    # * filter var.internet_gateway_route_rules for routes with "drg" as destination
    # * and steer traffic to the attached DRG if available
    for_each = var.internet_gateway_route_rules != null ? { for k, v in var.internet_gateway_route_rules : k => v
    if v.network_entity_id == "drg" && var.attached_drg_id != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = var.attached_drg_id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.internet_gateway_route_rules for routes with "internet_gateway" as destination
    # * and steer traffic to the module created Internet Gateway
    for_each = var.internet_gateway_route_rules != null ? { for k, v in var.internet_gateway_route_rules : k => v
    if v.network_entity_id == "internet_gateway" } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_internet_gateway.ig[0].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.internet_gateway_route_rules for routes with "lpg@" as destination
    # * and steer traffic to the attached LPG if available
    for_each = var.internet_gateway_route_rules != null ? { for k, v in var.internet_gateway_route_rules : k => v
    if startswith(v.network_entity_id, "lpg@") && var.local_peering_gateways != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_local_peering_gateway.lpg[split("@", route_rules.value.network_entity_id)[1]].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.internet_gateway_route_rules for generic routes
    # * can take any Named Value : String, Input Variable, Local Value, Data Source, Resource, Module Output ...
    # * useful for gateways that are not managed by the module
    for_each = var.internet_gateway_route_rules != null ? { for k, v in var.internet_gateway_route_rules : k => v
    if contains(["drg", "internet_gateway"], v.network_entity_id) == false && startswith(v.network_entity_id, "lpg@") == false } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
  }

  vcn_id = oci_core_vcn.vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_internet_gateway == true ? 1 : 0
}

#######################
# Service Gateway (SGW)
#######################
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
  count = var.create_service_gateway == true ? 1 : 0
}

resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "none" ? var.service_gateway_display_name : "${var.label_prefix}-${var.service_gateway_display_name}"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  services {
    service_id = lookup(data.oci_core_services.all_oci_services[0].services[0], "id")
  }

  vcn_id = oci_core_vcn.vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_service_gateway == true ? 1 : 0
}

resource "oci_core_route_table" "service_gw" {
  compartment_id = var.compartment_id
  display_name   = local.service_gateway_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  dynamic "route_rules" {
    # * If Service Gateway is created with the module, automatically creates a rule to handle traffic for "all services" through Service Gateway
    for_each = var.create_service_gateway == true ? [1] : []

    content {
      destination       = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.service_gateway[0].id
      description       = "Terraformed - Auto-generated at Service Gateway creation: All Services in region to Service Gateway"
    }
  }

  vcn_id = oci_core_vcn.vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_service_gateway == true ? 1 : 0
}

###################
# NAT Gateway (NGW)
###################
resource "oci_core_public_ip" "nat_gateway_public_ip" {
  count          = var.create_nat_gateway == true && var.nat_gateway_public_ip_id == "RESERVED" ? 1 : 0
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags
  display_name   = var.label_prefix == "none" ? var.nat_gateway_display_name : "${var.label_prefix}-${var.nat_gateway_display_name}"
}

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "none" ? var.nat_gateway_display_name : "${var.label_prefix}-${var.nat_gateway_display_name}"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  public_ip_id = var.nat_gateway_public_ip_id != "none" ? var.nat_gateway_public_ip_id != "RESERVED" ? var.nat_gateway_public_ip_id : join(",", oci_core_public_ip.nat_gateway_public_ip.*.id) : null

  vcn_id = oci_core_vcn.vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_nat_gateway == true ? 1 : 0
}

# special fix due to bug introduced in #101 which causes destruction and recreation of subnets
# for existing users

resource "oci_core_route_table" "nat" {
  compartment_id = var.compartment_id
  display_name   = local.nat_gateway_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  route_rules {
    # * With this route table, NAT Gateway is always declared as the default gateway
    destination       = local.anywhere
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
    description       = "Terraformed - Auto-generated at NAT Gateway creation: NAT Gateway as default gateway"
  }

  # bring this block back to fix #101
  dynamic "route_rules" {
    # * If Service Gateway is created with the module, automatically creates a rule to handle traffic for "all services" through Service Gateway
    for_each = var.create_service_gateway == true ? [1] : []

    content {
      destination       = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.service_gateway[0].id
      description       = "Terraformed - Auto-generated at Service Gateway creation: All Services in region to Service Gateway"
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "drg" as destination
    # * and steer traffic to the attached DRG if available
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if v.network_entity_id == "drg" && var.attached_drg_id != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = var.attached_drg_id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "nat_gateway" as destination
    # * and steer traffic to the module created NAT Gateway
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if v.network_entity_id == "nat_gateway" } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "lpg@" as destination
    # * and steer traffic to the attached LPG if available
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if startswith(v.network_entity_id, "lpg@") && var.local_peering_gateways != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_local_peering_gateway.lpg[split("@", route_rules.value.network_entity_id)[1]].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for generic routes
    # * can take any Named Value : String, Input Variable, Local Value, Data Source, Resource, Module Output ...
    # * useful for gateways that are not managed by the module
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if contains(["drg", "nat_gateway"], v.network_entity_id) == false && startswith(v.network_entity_id, "lpg@") == false } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
  }

  vcn_id = oci_core_vcn.vcn.id

  # ignore changes to route rules to avoid recreation issues due to #101.
  # A fix may still be needed for when new custom route rules are added.

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_nat_gateway ? 1 : 0
}

resource "oci_core_route_table" "igw_ngw_mixed_route_id" {
  compartment_id = var.compartment_id
  display_name   = var.igw_ngw_mixed_route_table_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  route_rules {
    # * With this route table, NAT Gateway is always declared as the default gateway for IPv4
    destination       = local.anywhere
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
    description       = "Terraformed - Auto-generated at NAT Gateway creation: NAT Gateway as default gateway for IPv4"
  }

  route_rules {
    # * With this route table, IGW Gateway is always declared as the default gateway for IPv6
    destination       = local.anywhere_ipv6
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ig[0].id
    description       = "Terraformed - Auto-generated at NAT Gateway creation: IGW Gateway as default gateway for IPv6"
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "drg" as destination
    # * and steer traffic to the attached DRG if available
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if v.network_entity_id == "drg" && var.attached_drg_id != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = var.attached_drg_id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "nat_gateway" as destination
    # * and steer traffic to the module created NAT Gateway
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if v.network_entity_id == "nat_gateway" } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for routes with "lpg@" as destination
    # * and steer traffic to the attached LPG if available
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if startswith(v.network_entity_id, "lpg@") && var.local_peering_gateways != null } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = oci_core_local_peering_gateway.lpg[split("@", route_rules.value.network_entity_id)[1]].id
      description       = route_rules.value.description
    }
  }

  dynamic "route_rules" {
    # * filter var.nat_gateway_route_rules for generic routes
    # * can take any Named Value : String, Input Variable, Local Value, Data Source, Resource, Module Output ...
    # * useful for gateways that are not managed by the module
    for_each = var.nat_gateway_route_rules != null ? { for k, v in var.nat_gateway_route_rules : k => v
    if contains(["drg", "nat_gateway"], v.network_entity_id) == false && startswith(v.network_entity_id, "lpg@") == false } : {}

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
  }

  vcn_id = oci_core_vcn.vcn.id

  # ignore changes to route rules to avoid recreation issues due to #101.
  # A fix may still be needed for when new custom route rules are added.

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_nat_gateway && var.create_internet_gateway && var.enable_ipv6 ? 1 : 0
}


#############################
# Local Peering Gateway (LPG)
#############################

resource "oci_core_local_peering_gateway" "lpg" {
  for_each       = var.local_peering_gateways != null ? var.local_peering_gateways : {}
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "none" ? each.key : "${var.label_prefix}-${each.key}"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  vcn_id = oci_core_vcn.vcn.id

  #Optional
  peer_id        = can(each.value.peer_id) == false ? null : each.value.peer_id
  route_table_id = can(each.value.route_table_id) == false ? null : each.value.route_table_id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}
