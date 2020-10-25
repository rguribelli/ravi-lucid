data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  map_public_ip_on_launch = "false"
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_subnet" "public" {
  count                   = "2"
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidr, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = "true"
}

resource "aws_internet_gateway" "igw" {
  depends_on = [aws_vpc.main]
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.main.id
route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  count          = "2"
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.rtb_public.id
}


data "aws_ami" "amazon-linux-2" {
 most_recent = true
 owners = ["amazon"]


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

resource "aws_launch_configuration" "as_conf" {
  name          = "web_config"
  image_id      = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]
  key_name      = var.key_name
  user_data = <<-EOF
                #!/bin/bash
                cat > /var/www/html/wp-config.php <<'_END'
                <?php
                define( 'DB_NAME', 'var.db_name' );
                define( 'DB_USER', 'var.username' );
                define( 'DB_PASSWORD', 'var.password' );
                define( 'DB_HOST', 'var.rds' );
                define( 'DB_CHARSET', 'utf8' );
                define( 'DB_COLLATE', '' );
                define( 'AUTH_KEY',         'put your unique phrase here' );
                define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
                define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
                define( 'NONCE_KEY',        'put your unique phrase here' );
                define( 'AUTH_SALT',        'put your unique phrase here' );
                define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
                define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
                define( 'NONCE_SALT',       'put your unique phrase here' );
                $table_prefix = 'wp_';
                define( 'WP_DEBUG', false );
                require_once ABSPATH . 'wp-settings.php';
                _END
                EOF
   lifecycle {
    create_before_destroy = true
  }
}

### Creating Security Group for EC2
resource "aws_security_group" "instance" {
  name = "aws-ec2-asg"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Creating Security Group for ALB
resource "aws_security_group" "lb_sg" {
  name = "aws-alb-asg"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "bar" {
  name                 = "as_asg"
  depends_on           = [aws_launch_configuration.as_conf,aws_lb_target_group.test]
  max_size             = 1
  min_size             = 1
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = [aws_subnet.private.id]
  health_check_type    = "EC2"
  target_group_arns    = [aws_lb_target_group.test.arn]
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public.*.id

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  depends_on = [aws_vpc.main]
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "front_end" {
  depends_on        = [aws_lb.test,aws_lb_target_group.test]
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}