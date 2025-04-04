# Copyright (c) 2022 Oracle Corporation and/or affiliates.  All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  dhcp_default_options = data.oci_core_dhcp_options.dhcp_options.options.0.id
  // Tenancy-specific availability domains in region
  // Common reference for data source re-used throughout module
  ads = data.oci_identity_availability_domains.all.availability_domains

  // Map of parsed availability domain numbers to tenancy-specific names
  // Used by resources with AD placement for generic selection
  ad_numbers_to_names = local.ads != null ? {
    for ad in local.ads : parseint(substr(ad.name, -1, -1), 10) => ad.name
  } : { -1 : "" } # Fallback handles failure when unavailable but not required

  // List of availability domain numbers in region
  // Used to intersect desired AD lists against presence in region
  ad_numbers = local.ads != null ? sort(keys(local.ad_numbers_to_names)) : []
}

data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_id
}

resource "oci_core_subnet" "vcn_subnet" {
  for_each = var.subnets

  cidr_block          = each.value.cidr_block
  compartment_id      = var.compartment_id
  vcn_id              = var.vcn_id
  availability_domain = lookup(each.value, "availability_domain", null) != null ? local.ad_numbers_to_names[each.value.availability_domain] : null

  defined_tags    = var.defined_tags
  dhcp_options_id = local.dhcp_default_options
  display_name    = lookup(each.value, "name", each.key)
  dns_label       = lookup(each.value, "dns_label", null)
  freeform_tags   = var.freeform_tags
  #commented for IPV6 support
  # ipv6cidr_block             = var.enable_ipv6 == false ? null : each.value.ipv6cidr_block
  ipv6cidr_blocks            = var.enable_ipv6 == false ? null : each.value.ipv6cidr_blocks
  prohibit_internet_ingress  = lookup(each.value, "type", "public") == "public" ? false : true
  # prohibit_public_ip_on_vnic = lookup(each.value, "type", "public") == "public" ? false : true
  route_table_id = lookup(each.value, "type", "public") == "public" ? (
    lookup(each.value, "igw_ngw_mixed_rt", false)  == true ? 
      var.igw_ngw_mixed_route_id : 
      var.ig_route_id
    ) : var.nat_route_id

  security_list_ids = null

  lifecycle {
    ignore_changes = [defined_tags, dns_label, freeform_tags]
  }
}

data "oci_core_dhcp_options" "dhcp_options" {

  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
}
