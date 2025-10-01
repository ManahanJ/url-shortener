# OPA Networking Policies for URL Shortener Infrastructure
# Enforces network security and proper subnet configuration

package terraform.networking

import rego.v1

# DENY rule: Private subnets must not have routes to Internet Gateway
deny contains msg if {
    route_table := input.resource_changes[_]
    route_table.type == "aws_route_table"

    # Check if this is a private subnet route table
    tags := object.get(route_table.change.after, "tags", {})
    contains(lower(tags.Name), "private")

    # Check for routes to Internet Gateway
    routes := object.get(route_table.change.after, "route", [])
    route := routes[_]
    route.gateway_id
    startswith(route.gateway_id, "igw-")

    msg := sprintf("Private route table '%s' must not have routes to Internet Gateway", [
        route_table.address
    ])
}

# DENY rule: Database subnets must be in private subnets only
deny contains msg if {
    subnet := input.resource_changes[_]
    subnet.type == "aws_subnet"
    tags := object.get(subnet.change.after, "tags", {})

    # Check if this is a database subnet
    subnet_name := tags.Name
    is_database_subnet(subnet_name)

    # Database subnets must not be public
    subnet.change.after.map_public_ip_on_launch == true

    msg := sprintf("Database subnet '%s' must not have map_public_ip_on_launch enabled", [
        subnet.address
    ])
}

# DENY rule: Security groups must follow least privilege principle
deny contains msg if {
    sg := input.resource_changes[_]
    sg.type == "aws_security_group"

    ingress := sg.change.after.ingress[_]

    # Check for overly permissive port ranges
    port_range := ingress.to_port - ingress.from_port
    port_range > 100

    msg := sprintf("Security group '%s' has overly broad port range (%d-%d). Use specific ports when possible", [
        sg.address,
        ingress.from_port,
        ingress.to_port
    ])
}

# DENY rule: No SSH access from anywhere
deny contains msg if {
    sg := input.resource_changes[_]
    sg.type == "aws_security_group"

    ingress := sg.change.after.ingress[_]
    ingress.from_port == 22
    ingress.to_port == 22

    # Check for public SSH access
    public_ssh_access(ingress)

    msg := sprintf("Security group '%s' allows SSH access from public internet. Restrict to specific IP ranges", [
        sg.address
    ])
}

# DENY rule: Database ports should not be accessible from public internet
deny contains msg if {
    sg := input.resource_changes[_]
    sg.type == "aws_security_group"

    ingress := sg.change.after.ingress[_]

    # Common database ports
    database_ports := {5432, 3306, 1433, 5984, 6379, 27017}
    ingress.from_port in database_ports

    # Check for public access
    public_access_detected(ingress)

    msg := sprintf("Security group '%s' allows database port %d from public internet", [
        sg.address,
        ingress.from_port
    ])
}

# DENY rule: VPC must have DNS support enabled
deny contains msg if {
    vpc := input.resource_changes[_]
    vpc.type == "aws_vpc"

    vpc.change.after.enable_dns_support != true

    msg := sprintf("VPC '%s' must have DNS support enabled", [
        vpc.address
    ])
}

# DENY rule: VPC must have DNS hostnames enabled
deny contains msg if {
    vpc := input.resource_changes[_]
    vpc.type == "aws_vpc"

    vpc.change.after.enable_dns_hostnames != true

    msg := sprintf("VPC '%s' must have DNS hostnames enabled", [
        vpc.address
    ])
}

# WARN rule: Subnets should be distributed across multiple AZs
warn contains msg if {
    # Count subnets per AZ
    az_counts := {az: subnet_count |
        subnet := input.resource_changes[_]
        subnet.type == "aws_subnet"
        az := subnet.change.after.availability_zone
        subnet_count := count([s | s := input.resource_changes[_]; s.type == "aws_subnet"; s.change.after.availability_zone == az])
    }

    # Check if any AZ has significantly more subnets than others
    counts := [subnet_count | az_counts[_] = subnet_count]
    max_count := max(counts)
    min_count := min(counts)

    max_count > min_count + 1

    msg := "Subnets should be evenly distributed across availability zones for better fault tolerance"
}

# WARN rule: NAT Gateways should be in multiple AZs for high availability
warn contains msg if {
    nat_gateways := [ng |
        ng := input.resource_changes[_]
        ng.type == "aws_nat_gateway"
    ]

    count(nat_gateways) == 1

    msg := "Consider deploying NAT Gateways in multiple AZs for high availability"
}

# Helper functions
public_access_detected(rule) if {
    rule.cidr_blocks[_] == "0.0.0.0/0"
}

public_access_detected(rule) if {
    rule.ipv6_cidr_blocks[_] == "::/0"
}

public_ssh_access(rule) if {
    rule.cidr_blocks[_] == "0.0.0.0/0"
}

public_ssh_access(rule) if {
    rule.ipv6_cidr_blocks[_] == "::/0"
}

# Helper function to check if subnet is a database subnet
is_database_subnet(subnet_name) if {
    contains(subnet_name, "database")
}

is_database_subnet(subnet_name) if {
    contains(subnet_name, "db")
}

is_database_subnet(subnet_name) if {
    contains(subnet_name, "Database")
}

is_database_subnet(subnet_name) if {
    contains(subnet_name, "DB")
}