// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

provider "aws" {
  region     = "${var.region}"
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "cluster" {
  name     = "cluster-${var.ProjectTag}-${var.Environment}"
  tags = {
    Name = "ECS-Cluster"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

module "network" {
  source = "./network"

  ProjectTag =  "${var.ProjectTag}"
  Environment =  "${var.Environment}"
  ingress_cidr = "${var.ingress_cidr}"
  region = "${var.region}"
}

resource "aws_ecs_task_definition" "proxy" {
  family = "proxy-${var.ProjectTag}-${var.Environment}"
  container_definitions = <<EOF
[
  {
    "name": "proxy",
    "image": "${var.NginxImage}",
    "cpu": 512,
    "memory": 1024,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ],
    "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "${aws_cloudwatch_log_group.proxy_task_logs.name}",
                    "awslogs-region": "${var.region}",
                    "awslogs-stream-prefix": "proxy"
                }
    },
    "environment": [
        {
            "name": "PROXY_FOR",
            "value": "${var.ProxyFor}"
        }
    ]
  }
]
EOF

  network_mode = "awsvpc"
  execution_role_arn = "${aws_iam_role.exec_role.arn}"
  cpu = 512
  memory = 1024
  requires_compatibilities = ["FARGATE"]
  tags = {
    Name = "proxy"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role" "exec_role" {
  name_prefix = "exec_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ecs-tasks.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags = {
    Name = "exec_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  role       = "${aws_iam_role.exec_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "proxy_lb" {
  name = "proxy-lb-${var.ProjectTag}-${var.Environment}"
  internal           = false
  load_balancer_type = "network"
  subnet_mapping {
    subnet_id     = "${module.network.SubnetIdPublicA}"
    allocation_id = aws_eip.lb_eip1.id
  }

  subnet_mapping {
    subnet_id     = "${module.network.SubnetIdPublicB}"
    allocation_id = aws_eip.lb_eip2.id
  }

  tags = {
    Name = "proxy_lb"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_eip" "lb_eip1" {
  vpc      = true
}
resource "aws_eip" "lb_eip2" {
  vpc      = true
}

resource "aws_ecs_service" "proxy_service" {
  name = "proxy_svc-${var.ProjectTag}-${var.Environment}"
  cluster         = "${aws_ecs_cluster.cluster.id}"
  task_definition = "${aws_ecs_task_definition.proxy.arn}"
  desired_count   = 1
  launch_type = "FARGATE"

  load_balancer {
    target_group_arn = "${aws_lb_target_group.proxy_lb_group.arn}"
    container_name   = "proxy"
    container_port   = 443
  }

  network_configuration {
      subnets = ["${module.network.SubnetIdPrivateA}", "${module.network.SubnetIdPrivateB}"]
      security_groups = ["${aws_security_group.proxy_lb_only.id}"]
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }

  depends_on = [
    "aws_lb_listener.proxy_lb_list"
  ]
}

resource "aws_security_group" "proxy_lb_only" {
  name_prefix        = "proxy_lb_only"
  description = "Allow incoming traffic from NLB"
  vpc_id      = "${module.network.VpcId}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.ingress_cidr}"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${module.network.VpcCidr}"]
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
    Name = "proxy_lb_only"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_cloudwatch_log_group" "proxy_task_logs" {
  name_prefix = "proxy_logs-${var.ProjectTag}-${var.Environment}"

  tags = {
    Name = "proxy_logs"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_lb_listener" "proxy_lb_list" {
  load_balancer_arn = "${aws_lb.proxy_lb.arn}"
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.proxy_lb_group.arn}"
  }
}

resource "aws_lb_target_group" "proxy_lb_group" {
  name = "proxy-group-${var.ProjectTag}-${var.Environment}"
  port     = 443
  protocol = "TCP"
  vpc_id      = "${module.network.VpcId}"
  target_type = "ip"
  stickiness {
    enabled = false
    type = "lb_cookie"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high" {
  alarm_name          = "${var.ProjectTag}-${var.Environment}-CPU-Utilization-High-${var.ecs_as_cpu_high_threshold_per}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.ecs_as_cpu_high_threshold_per}"

  dimensions = {
    ClusterName = "${aws_ecs_cluster.cluster.name}"
    ServiceName = "${aws_ecs_service.proxy_service.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.app_up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_low" {
  alarm_name          = "${var.ProjectTag}-${var.Environment}-CPU-Utilization-Low-${var.ecs_as_cpu_low_threshold_per}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.ecs_as_cpu_low_threshold_per}"

  dimensions = {
    ClusterName = "${aws_ecs_cluster.cluster.name}"
    ServiceName = "${aws_ecs_service.proxy_service.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.app_down.arn}"]
}

resource "aws_appautoscaling_policy" "app_up" {
  name               = "app-scale-up"
  service_namespace  = "${aws_appautoscaling_target.app_scale_target.service_namespace}"
  resource_id        = "${aws_appautoscaling_target.app_scale_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.app_scale_target.scalable_dimension}"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "app_down" {
  name               = "app-scale-down"
  service_namespace  = "${aws_appautoscaling_target.app_scale_target.service_namespace}"
  resource_id        = "${aws_appautoscaling_target.app_scale_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.app_scale_target.scalable_dimension}"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_appautoscaling_target" "app_scale_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.proxy_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  max_capacity       = "${var.ecs_autoscale_max_instances}"
  min_capacity       = "${var.ecs_autoscale_min_instances}"
  role_arn           = "${aws_iam_role.autoscale_role.arn}"
}

resource "aws_iam_role" "autoscale_role" {
  name_prefix = "autoscale_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "application-autoscaling.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags = {
    Name = "autoscale_role"
    Project = "${var.ProjectTag}"
    Environment = "${var.Environment}"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_autoscale_policy" {
  role       = "${aws_iam_role.autoscale_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}
