resource "aws_cloudwatch_log_group" "ecs_run_task" {
  name = "/aws/ecs/run-task"
}


resource "aws_cloudwatch_event_rule" "run_task" {
  name                = "ScheduledECSRunTask"
  description         = "This rule is used to the trigger for ECS RunTask"
  schedule_expression = "cron(0/5 * * * ? *)"
}


resource "aws_cloudwatch_event_target" "run_task" {
  target_id = "run-task-every-5min"
  arn       = aws_ecs_cluster.ecs-deploy.arn
  rule      = aws_cloudwatch_event_rule.run_task.name
  role_arn  = aws_iam_role.run_task.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.run_task.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets = aws_subnet.private-subnet[*].id
    }
  }
}


resource "aws_ecs_task_definition" "run_task" {
  family                   = "run-task"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = jsonencode(
[
  {
    "name": "scheduled_task",
    "image": "busybox",
    "command": [
      "echo",
      "'hello world'"
    ],
    "essential": true,
    "cpu": 100,
    "memory": 512,
    "memoryReservation": 256,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/aws/ecs/run-task",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "run-task"
      }
    }
  }
])
}


resource "aws_iam_role" "run_task" {
  name = "ecsRunTaskRole"

  assume_role_policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
})
}

resource "aws_iam_role_policy" "run_task" {
  name = "amazonEcsRunTaskPolicy"
  role = aws_iam_role.run_task.id

  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*",
      "Condition": {
        "StringLike" : {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "ecs:RunTask",
      "Resource": replace(aws_ecs_task_definition.run_task.arn, "/:\\d+$/", ":*")
    }
  ]
})
}
