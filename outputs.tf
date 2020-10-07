// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

output "NlbDns" {
  value = "https://${aws_lb.proxy_lb.dns_name}"
}

