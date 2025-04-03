# Copyright (c) 2021, Oracle Corporation and/or affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

# VCN default Security List Lockdown
// See Issue #22 for the reasoning
resource "oci_core_default_security_list" "lockdown" {
  // If variable is true, removes all rules from default security list
  manage_default_resource_id = oci_core_vcn.vcn.default_security_list_id

  count = var.lockdown_default_seclist == true ? 1 : 0

  lifecycle {
    ignore_changes = [egress_security_rules, ingress_security_rules, defined_tags]
  }

}

resource "oci_core_default_security_list" "restore_default" {
  // If variable is false, restore all default rules to default security list
  manage_default_resource_id = oci_core_vcn.vcn.default_security_list_id

  egress_security_rules {
    // allow all egress traffic
    destination = local.anywhere
    protocol    = "all"
  }

  dynamic "egress_security_rules" {
    //allow all egress traffic for IPv6
    for_each = var.enable_ipv6 ? [0] : []
    content {
      destination = local.anywhere_ipv6
      protocol    = "all"
    }
  }

  ingress_security_rules {
    // allow all SSH
    protocol = "6"
    source   = local.anywhere
    tcp_options {
      min = 22
      max = 22
    }
  }

  dynamic "ingress_security_rules" {
    //allow all SSH for IPv6
    for_each = var.enable_ipv6 ? [0] : []
    content {
      protocol = "6"
      source   = local.anywhere_ipv6
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    // allow ICMP for all type 3 code 4
    protocol = "1"
    source   = local.anywhere

    icmp_options {
      type = "3"
      code = "4"
    }
  }

  dynamic "ingress_security_rules" {
    //allow ICMPv6 for all type 2 code 0 (Packet Too Big)
    for_each = var.enable_ipv6 ? [0] : []
    content {
      protocol = "58"
      source   = local.anywhere_ipv6
      icmp_options {
        type = "2"
        code = "0"
      }
    }
  }

  dynamic "ingress_security_rules" {
    //allow all ICMP from all VCN CIDRs
    for_each = oci_core_vcn.vcn.cidr_blocks
    iterator = vcn_cidr
    content {
      protocol = "1"
      source   = vcn_cidr.value
      icmp_options {
        type = "3"
      }
    }
  }

  lifecycle {
    ignore_changes = [egress_security_rules, ingress_security_rules, defined_tags]
  }

  count = var.lockdown_default_seclist == false ? 1 : 0
}
