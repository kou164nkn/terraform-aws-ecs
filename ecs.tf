# === ECS Cluster =======================================
resource "aws_ecs_cluster" "ecs-deploy" {
  name = "ecs-deploy_ecs-cluster"
}
# =======================================================


# === CloudWatch LogGroup ===============================
resource "aws_cloudwatch_log_group" "ecs-deploy" {
  name = "/aws/ecs/ecs-deploy"

  tags = {
    foo = "bar"
  }
}
# =======================================================


# === IAM for executing task ============================
data "aws_iam_role" "official-ecs-exec" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_role" "ecs-exec" {
  name = "ecsExecutionRoleForEcsDeploy"

  assume_role_policy = <<EOF
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
}
EOF
}

resource "aws_iam_role_policy" "ecs-exec" {
  name = "amazonEcsExecutionRolePolicyForEcsDeploy"
  role = aws_iam_role.ecs-exec.id

  policy = <<EOF
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
}
EOF
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
resource "aws_ecs_service" "ecs-deploy_nginx" {
  name            = "ecs-deploy_nginx"
  cluster         = aws_ecs_cluster.ecs-deploy.id
  task_definition = aws_ecs_task_definition.ecs-deploy_nginx.arn

  desired_count    = 2
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags   = "TASK_DEFINITION"

  health_check_grace_period_seconds = 20

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-deploy.arn
    container_name   = "nginx"
    container_port   = 80
  }

  network_configuration {
    subnets = aws_subnet.private-subnet[*].id

    security_groups = [ aws_security_group.ecs-deploy.id ]
  }

  depends_on = [ aws_lb_listener.ecs-deploy ]
}


resource "aws_ecs_task_definition" "ecs-deploy_nginx" {
  family                   = "ecs-deploy_nginx"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = <<CONTAINER_DEF
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
        "awslogs-group": "/aws/ecs/ecs-deploy",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "ecs-deploy"
      }
    }
  }
]
CONTAINER_DEF
}
# =======================================================