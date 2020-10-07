// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

output "VpcId" {
  value = "${aws_vpc.VPC.id}"
}
output "VpcCidr" {
  value = "${aws_vpc.VPC.cidr_block}"
}
output "SubnetIdPublicA" {
  value = "${aws_subnet.SubnetPublicA.id}"
}
output "SubnetIdPublicB" {
  value = "${aws_subnet.SubnetPublicB.id}"
}
output "SubnetIdPrivateA" {
  value = "${aws_subnet.SubnetPrivateA.id}"
}
output "SubnetIdPrivateB" {
  value = "${aws_subnet.SubnetPrivateB.id}"
}
output "RTIdPublic" {
  value = "${aws_route_table.RouteTablePublic.id}"
}
output "RTIdPrivateA" {
  value = "${aws_route_table.RouteTablePrivateA.id}"
}
output "RTIdPrivateB" {
  value = "${aws_route_table.RouteTablePrivateB.id}"
}
