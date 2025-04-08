## Terraform Options

### Provider

| Parameter | Description | Type        | Default |
| --------- | ----------- | ----------- | ------- |
| region | Region where to provision the vcn. List of regions. *Required*. | string | |

### General OCI

| Parameter | Description | Type        | Default |
| --------- | ----------- | ----------- | ------- |
| compartment_id | Compartment id where the VCN Cluster will be provisioned. *Required*. | string | |
| label_prefix | a string to be prepended to the name of resources.  *Required*. | string |none |
| freeform_tags | simple key-value pairs to tag the resources created specified in the form of a map | map(any)|freeform_tags = { environment = "dev" } |
| defined_tags | predefined and scoped to a namespace to tag the resources created using defined tags. | map(string) |null |

### VCN

| Parameter | Description | Type        | Default |
| --------- | ----------- | ----------- | ------- |
| attached_drg_id | DRG OCID to be attached to the VCN. | string ||
| create_internet_gateway | Whether to create an Internet Gateway. | bool | false|
| create_nat_gateway | Whether to create an NAT gateway. | bool | false|
| create_service_gateway | Whether to create a service gateway to use Oracle Services. | bool | false|
| enable_ipv6 | (Updatable) Whether IPv6 is enabled for the VCN. If enabled, Oracle will assign the VCN a IPv6 /56 CIDR block. | bool | false|
| igw_ngw_mixed_route_table_display_name | (Updatable) Name of the Mixed Route Table (NGW for IPv4, IGW for IPv6). Does not have to be unique. | string | igw-ngw-mixed-gateway |
| internet_gateway_display_name | (Updatable) Name of Internet Gateway. Does not have to be unique.| string | internet-gateway|
| internet_gateway_route_rules | (Updatable) List of routing rules to add to Internet Gateway Route Table.| list(map(string)) | null|
| local_peering_gateways | Map of Local Peering Gateways to attach to the VCN | map(any) | null|
| lockdown_default_seclist | Whether to remove all default security rules from the VCN Default Security List | bool | true|
| nat_gateway_display_name | (Updatable) Name of NAT Gateway. It does not have to be unique. | string | nat-gateway|
| nat_gateway_public_ip_id | OCID of reserved IP address for NAT gateway. If default value "none" is used, then a public IP address is selected from Oracle’s public IP pool. | string | none|
| nat_gateway_route_rules | (Updatable) List of routing rules to add to NAT Gateway Route Table | list(map(string)) | null|
| service_gateway_display_name | (Updatable) Name of Service Gateway. Does not have to be unique. | string | service-gateway|
| vcn_byoipv6cidr_details | (Optional)List of BYOIPv6 CIDR blocks to be used for the VCN. | list(object) | [] |
| vcn_cidrs | (Updatable) The list of IPv4 CIDR blocks the VCN will use. The CIDR block specified for the VCN must not overlap with the CIDR block of another network. | string | ["10.0.0.0/16"]|
| vcn_dns_label | (Optional)A DNS label for the VCN, used in conjunction with the VNIC’s hostname and subnet’s DNS label to form a fully qualified domain name (FQDN) for each VNIC within this subnet. DNS resolution for hostnames in the VCN is disabled if null. | string | vcnmodule|
| vcn_ipv6private_cidr_blocks | (Optional)List of IPv6 private CIDR blocks to be used for the VCN. | list(string) | []|
| vcn_is_oracle_gua_allocation_enabled | (Optional)If Oracle will assign the VCN a IPv6 /56 CIDR block when IPv6 is enabled. | bool | true|
| vcn_name | (Optional)(Updatable) The name of the VCN that will be appended to the label_prefix. | string | vcn|

### Subnets

| Parameter | Description | Type        | Default |
| --------- | ----------- | ----------- | ------- |
| subnets | Subnets to be created in the VCN | any |{}|
