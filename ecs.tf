# === ECS Cluster =======================================
resource "aws_ecs_cluster" "ecs-deploy" {
  name = "ecs-deploy_ecs-cluster"
}
# =======================================================


# === IAM for Task Role =================================
resource "aws_iam_role" "task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
})
}

resource "aws_iam_role_policy" "task_role" {
  name = "ecsTaskExecuteCommandRolePolicy"
  role = aws_iam_role.task_role.id

  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    }
  ]
})
}
# =======================================================


# === IAM for executing task ============================
data "aws_iam_role" "official-ecs-exec" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_role" "ecs-exec" {
  name = "ecsExecutionRoleForEcsDeploy"

  assume_role_policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
            "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

resource "aws_iam_role_policy" "ecs-exec" {
  name = "amazonEcsExecutionRolePolicyForEcsDeploy"
  role = aws_iam_role.ecs-exec.id

  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
})
}
# =======================================================


# === SecurityGroup for ECS Service =====================
resource "aws_security_group" "ecs-deploy" {
  name        = "allow_inbound_to_ecs"
  description = "Allow inbound traffic to ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ aws_vpc.main.cidr_block ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# =======================================================


# === ECS Service for nginx =============================
resource "aws_cloudwatch_log_group" "ecs_nginx" {
  name = "/aws/ecs/nginx"
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = aws_ecs_cluster.ecs-deploy.id
  task_definition = aws_ecs_task_definition.nginx.arn

  desired_count    = 2
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags   = "TASK_DEFINITION"

  enable_execute_command = true

  health_check_grace_period_seconds = 20

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_nginx.arn
    container_name   = "nginx"
    container_port   = 80
  }

  network_configuration {
    subnets = aws_subnet.private-subnet[*].id

    security_groups = [ aws_security_group.ecs-deploy.id ]
  }

  depends_on = [ aws_lb_listener.ecs-deploy ]
}


resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = jsonencode(
[
  {
    "name": "nginx",
    "image": "nginx",
    "essential": true,
    "cpu": 100,
    "memory": 512,
    "memoryReservation": 256,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/aws/ecs/nginx",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "nginx"
      }
    }
  }
])
}
# =======================================================


# === ECS Service for echo-server =======================
resource "aws_cloudwatch_log_group" "ecs_echo-server" {
  name = "/aws/ecs/echo-server"
}

resource "aws_ecs_service" "echo-server" {
  name            = "echo-server"
  cluster         = aws_ecs_cluster.ecs-deploy.id
  task_definition = aws_ecs_task_definition.echo-server.arn

  desired_count    = 2
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags   = "TASK_DEFINITION"

  enable_execute_command = true

  health_check_grace_period_seconds = 20

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_echo-server.arn
    container_name   = "echo-server"
    container_port   = 80
  }

  network_configuration {
    subnets = aws_subnet.private-subnet[*].id

    security_groups = [ aws_security_group.ecs-deploy.id ]
  }

  depends_on = [ aws_lb_listener.ecs-deploy ]
}


resource "aws_ecs_task_definition" "echo-server" {
  family                   = "echo-server"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = jsonencode(
[
  {
    "name": "echo-server",
    "image": "hashicorp/http-echo",
    "command": [
      "-listen=:80",
      "-text='Hello World!!'"
    ],
    "essential": true,
    "cpu": 100,
    "memory": 512,
    "memoryReservation": 256,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/aws/ecs/echo-server",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "echo-server"
      }
    }
  }
])
}
# =======================================================


# === ECS Service like background process ===============
resource "aws_cloudwatch_log_group" "ecs_background_worker" {
  name = "/aws/ecs/background-worker"
}

resource "aws_ecs_service" "background_worker" {
  name            = "background-worker"
  cluster         = aws_ecs_cluster.ecs-deploy.id
  task_definition = aws_ecs_task_definition.background_worker.arn

  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags   = "TASK_DEFINITION"

  enable_execute_command = true

  network_configuration {
    subnets = aws_subnet.private-subnet[*].id

    security_groups = [ aws_security_group.ecs-deploy.id ]
  }
}


resource "aws_ecs_task_definition" "background_worker" {
  family                   = "background-worker"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = jsonencode(
[
  {
    "name": "background-worker",
    "image": "ghcr.io/kou164nkn/simple-rainbow:0.2.0",
    "essential": true,
    "cpu": 100,
    "memory": 512,
    "memoryReservation": 256,
    "healthCheck" : {
      "command": [ "CMD-SHELL", "ps ax | grep -v grep | grep simple-rainbow" ],
      "interval": 10,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 10
    },
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/aws/ecs/background-worker",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "background-worker"
      }
    }
  }
])
}
# =======================================================
