# === ALB =========================================
resource "aws_lb" "ecs-deploy" {
  name               = "ecs-deploy-lb"
  internal           = false
  load_balancer_type = "application"

  enable_deletion_protection = false

  security_groups = [ aws_security_group.alb.id ]

  subnets = aws_subnet.public-subnet[*].id
}
# =================================================


# === Listeners ===================================
resource "aws_lb_listener" "ecs-deploy" {
  load_balancer_arn = aws_lb.ecs-deploy.arn
  port              = 80
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  # certificate_arn   = var.cert_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "ecs-deploy_nginx" {
  listener_arn      = aws_lb_listener.ecs-deploy.arn
  priority          = 200

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-deploy_nginx.arn
  }
}

resource "aws_lb_listener_rule" "ecs-deploy_echo-server" {
  listener_arn      = aws_lb_listener.ecs-deploy.arn
  priority          = 100

  condition {
    path_pattern {
      values = ["/echo"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-deploy_echo-server.arn
  }
}
# =================================================


# === TargetGroups ================================
resource "aws_lb_target_group" "ecs-deploy_nginx" {
  name        = "ecs-deploy-nginx"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 10
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "ecs-deploy_echo-server" {
  name        = "ecs-deploy-ehco-server"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 10
    path                = "/health"
    port                = 80
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 3
  }
}
# =================================================


# === Security Group for ALB ======================
resource "aws_security_group" "alb" {
  name        = "allow_http_and_https"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*
resource "aws_security_group_rule" "alb" {
  type              = "ingress"
  to_port           = 443
  from_port         = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}
*/
# =================================================
