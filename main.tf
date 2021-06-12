
#========================================================
# Get Latest Packer AMI
#========================================================

data "aws_ami" "packer_ami" {
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["packer-Git-Website*"]
  }
}


#========================================================
# Creating TargetGroup For Application LoadBalancer
#========================================================

resource "aws_lb_target_group" "TG" {
  port     = 80
  vpc_id   = "${var.vpc_id}"
  protocol = "HTTP"
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
   }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.project}-TG"
  }
}

#========================================================
# Creating Application LoadBalancer
#========================================================

resource "aws_lb" "ALB" {
    
  name               = "Terraform-ALB"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${var.subnet1}" , "${var.subnet2}"] 
  security_groups    = [ aws_security_group.SG.id ]
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.TG ]
  tags = {
    Name = "${var.project}-ALB"
  }
}

#========================================================
# Creating http listener of application loadbalancer
#========================================================

resource "aws_lb_listener" "http" {
    
  load_balancer_arn = aws_lb.ALB.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  depends_on = [aws_lb.ALB]
}

#========================================================
# Creating https listener of application loadbalancer
#========================================================

resource "aws_lb_listener" "https" {

  load_balancer_arn = aws_lb.ALB.id
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.acm
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/html"
      message_body = "<h1><center>Sorry...! No such Site Found</center></h1>"
      status_code  = "200"
   }
  }

  depends_on = [aws_lb.ALB]
}

#========================================================
# forward website to target group
#========================================================

resource "aws_lb_listener_rule" "rule" {
    
  listener_arn = aws_lb_listener.https.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG.arn
  }

  condition {
    host_header {
      values = ["${var.domain_name}"]
    }
  }
}

#========================================================
#Security Group
#========================================================

resource "aws_security_group" "SG" {
    
  name        = "Terraform-SG"
  description = "allows all traffic both inbound and outbound"
  
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
    
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}-SG"
  }
}

#========================================================
# Launch Configuration 
#========================================================

resource "aws_launch_configuration" "LC" {
    
  image_id = data.aws_ami.packer_ami.id
  instance_type = var.ec2-type
  key_name = var.key_name 
  security_groups = [ aws_security_group.SG.id ]
  lifecycle {
    create_before_destroy = true
  }
}

#========================================================
# ASG
#========================================================

resource "aws_autoscaling_group" "ASG" {

  launch_configuration    =  aws_launch_configuration.LC.id
  vpc_zone_identifier     = ["${var.subnet1}" , "${var.subnet2}"]
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  target_group_arns       = [ aws_lb_target_group.TG.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "${var.project}-ASG"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

