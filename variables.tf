// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "ProjectTag" { 
    default="NginxProxy"
}
variable "Environment" { 
    default = "test"
}
variable "region" { }
variable "NginxImage" { }
variable "ProxyFor" { }
variable "ingress_cidr" { }
variable "ecs_as_cpu_low_threshold_per" {
  default = "20"
}
variable "ecs_as_cpu_high_threshold_per" {
  default = "80"
}
variable "ecs_autoscale_min_instances" {
  default = "1"
}
variable "ecs_autoscale_max_instances" {
  default = "8"
}

