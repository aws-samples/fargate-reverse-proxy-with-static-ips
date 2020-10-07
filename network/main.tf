// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_availability_zones" "available" {}

resource "aws_vpc" "VPC" {
  cidr_block       = "${var.vpccidr}"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "VPC"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags = {
    Name = "IGW"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_subnet" "SubnetPublicA" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPublicCIDRA}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "SubnetPublicA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPublicB" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPublicCIDRB}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "SubnetPublicB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPrivateA" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPrivateCIDRA}"
  map_public_ip_on_launch = "false"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "SubnetPrivateA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_subnet" "SubnetPrivateB" {
  vpc_id     = "${aws_vpc.VPC.id}"
  cidr_block = "${var.AppPrivateCIDRB}"
  map_public_ip_on_launch = "false"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "SubnetPrivateB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_route_table" "RouteTablePrivateA" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGatewayA.id}"
  }

  tags = {
    Name = "PrivateRTA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_route_table" "RouteTablePrivateB" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGatewayB.id}"
  }

  tags = {
    Name = "PrivateRTB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_route_table_association" "SubnetRouteTableAssociatePublicA" {
  subnet_id      = "${aws_subnet.SubnetPublicA.id}"
  route_table_id = "${aws_route_table.RouteTablePublic.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePublicB" {
  subnet_id      = "${aws_subnet.SubnetPublicB.id}"
  route_table_id = "${aws_route_table.RouteTablePublic.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePrivateA" {
  subnet_id      = "${aws_subnet.SubnetPrivateA.id}"
  route_table_id = "${aws_route_table.RouteTablePrivateA.id}"
}
resource "aws_route_table_association" "SubnetRouteTableAssociatePrivateB" {
  subnet_id      = "${aws_subnet.SubnetPrivateB.id}"
  route_table_id = "${aws_route_table.RouteTablePrivateB.id}"
}

resource "aws_nat_gateway" "NatGatewayA" {
  allocation_id = "${aws_eip.EIPNatGWA.id}"
  subnet_id     = "${aws_subnet.SubnetPublicA.id}"
  tags = {
    Name = "NatGWA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_nat_gateway" "NatGatewayB" {
  allocation_id = "${aws_eip.EIPNatGWB.id}"
  subnet_id     = "${aws_subnet.SubnetPublicB.id}"
  tags = {
    Name = "NatGWB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_eip" "EIPNatGWA" {
  vpc      = true
  tags = {
    Name = "EIPNatGWA"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_eip" "EIPNatGWB" {
  vpc      = true
  tags = {
    Name = "EIPNatGWB"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
resource "aws_route_table" "RouteTablePublic" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IGW.id}"
  }

  tags = {
    Name = "PublicRT"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_network_acl" "nacl_ingress" {
  vpc_id = aws_vpc.VPC.id
  subnet_ids = ["${aws_subnet.SubnetPublicA.id}", "${aws_subnet.SubnetPublicB.id}"]

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${var.ingress_cidr}"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "${var.vpccidr}"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "NACL"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_vpc_endpoint" "vpcs3" {
  vpc_id       = aws_vpc.VPC.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = ["${aws_route_table.RouteTablePrivateA.id}", "${aws_route_table.RouteTablePrivateB.id}", "${aws_route_table.RouteTablePublic.id}"]
}

resource "aws_vpc_endpoint" "vpcecrdkr" {
  vpc_id            = aws_vpc.VPC.id
  subnet_ids = ["${aws_subnet.SubnetPrivateA.id}", "${aws_subnet.SubnetPrivateB.id}"] 
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  auto_accept = "true"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpcesg.id,
  ]

  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "vpcecrapi" {
  vpc_id            = aws_vpc.VPC.id
  subnet_ids = ["${aws_subnet.SubnetPrivateA.id}", "${aws_subnet.SubnetPrivateB.id}"] 
  service_name      = "com.amazonaws.${var.region}.ecr.api"
  auto_accept = "true"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpcesg.id,
  ]

  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "vpccw" {
  vpc_id            = aws_vpc.VPC.id
  subnet_ids = ["${aws_subnet.SubnetPrivateA.id}", "${aws_subnet.SubnetPrivateB.id}"] 
  service_name      = "com.amazonaws.${var.region}.logs"
  auto_accept = "true"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpcesg.id,
  ]

  private_dns_enabled = true
}

resource "aws_security_group" "vpcesg" {
  name_prefix        = "vpcesg"
  description = "Allow access to VPC endpoints"
  vpc_id      = "${aws_vpc.VPC.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpccidr}"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-sg"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}
