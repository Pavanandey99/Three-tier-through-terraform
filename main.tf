#VPC
resource "aws_vpc" "vpc-new" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "New VPC"
    }
 
}

#Public Subnet-1
resource "aws_subnet" "Public-Subnet-1" {
    vpc_id = aws_vpc.vpc-new.id
    cidr_block = "10.0.0.0/24"
    tags = {
      Name = "Public-Subnet-1"
    }
    availability_zone = "eu-north-1a"
  
}

#Public Subnet-2
resource "aws_subnet" "Public-Subnet-2" {
    vpc_id = aws_vpc.vpc-new.id
    cidr_block = "10.0.1.0/24"
    tags = {
      Name = "Public-Subnet-2"
    }
    availability_zone = "eu-north-1b"
  
}

#Private Subnet-1
resource "aws_subnet" "Private-Subnet-1" {
    vpc_id = aws_vpc.vpc-new.id
    cidr_block = "10.0.2.0/24"
    tags = {
      Name = "Private-Subnet-1"
    }
    availability_zone = "eu-north-1a"
  
}

#Private Subnet-2
resource "aws_subnet" "Private-Subnet-2" {
    vpc_id = aws_vpc.vpc-new.id
    cidr_block = "10.0.3.0/24"
    tags = {
      Name = "Private-Subnet-2"
    }
    availability_zone = "eu-north-1b"
  
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc-new.id
}

#Nat
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.Public-Subnet-1.id
  depends_on    = [aws_internet_gateway.igw]
}

#Elastic IP
resource "aws_eip" "nat" {
    domain = "vpc"
  
}

#Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc-new.id
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public Subnets Route table"
  }
}

#RT associations
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.Public-Subnet-1.id
  route_table_id = aws_route_table.public.id

}

#RT associations
resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.Public-Subnet-2.id
  route_table_id = aws_route_table.public.id

}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc-new.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Subnets Route Table"
  }
}

# Associate Private Subnet-1
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.Private-Subnet-1.id
  route_table_id = aws_route_table.private.id
}

# Associate Private Subnet-2
resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.Private-Subnet-2.id
  route_table_id = aws_route_table.private.id
}

# Security Group
resource "aws_security_group" "SG" {
  name        = "SG"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.vpc-new.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Frontend Target Group
resource "aws_lb_target_group" "frontend-TG" {
  name        = "frontend-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-new.id  
  target_type = "instance"
  tags = {
    Name = "Forntend-TG"
  }

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# ALB
resource "aws_lb" "frontend-ALB" {
  name               = "frontend-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG.id]

  subnets = [aws_subnet.Public-Subnet-1.id , aws_subnet.Public-Subnet-2.id]
}

# Listener
resource "aws_lb_listener" "frontend-http" {
  load_balancer_arn = aws_lb.frontend-ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.frontend-TG.arn
  }
}

#Backend Target Group
resource "aws_lb_target_group" "backend-TG" {
  name        = "backend-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-new.id  
  target_type = "instance"
  tags = {
    Name = "Backend-TG"
  }

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# ALB
resource "aws_lb" "backend-ALB" {
  name               = "backend-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG.id]

  subnets = [aws_subnet.Public-Subnet-1.id , aws_subnet.Public-Subnet-2.id]
}

# Listener
resource "aws_lb_listener" "backend-http" {
  load_balancer_arn = aws_lb.backend-ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.backend-TG.arn
  }
}

resource "aws_secretsmanager_secret" "rds" {
  name = "threetiercredentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_version" {
  secret_id     = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({ username = var.db_username, password = var.db_password })
}

#Subnet Groups RDS
resource "aws_db_subnet_group" "RDS_Subnet_group" {
    subnet_ids = [aws_subnet.Private-Subnet-1.id , aws_subnet.Private-Subnet-2.id]
  
}

#RDS
resource "aws_db_instance" "RDS" {
    identifier = "rds"
    engine = "mysql"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    db_subnet_group_name = aws_db_subnet_group.RDS_Subnet_group.name
    vpc_security_group_ids = [aws_security_group.SG.id]
    username = var.db_username
    password = var.db_password
    skip_final_snapshot = true
    publicly_accessible = false
    db_name = "dev"
  
}

#KeyPair
resource "aws_key_pair" "KP" {
    key_name = "public"
    public_key = file("~/.ssh/id_ed25519.pub")

}

#frontend-ami-server
# resource "aws_instance" "frontend-ami" {
#   ami                         = "ami-0c1ac8a41498c1a9c"
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.Public-Subnet-1.id
#   vpc_security_group_ids      = [aws_security_group.SG.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.KP.key_name

#   tags = { Name = "frontend-ami-host" }

# }

#backend-ami-server
# resource "aws_instance" "backend-ami" {
#   ami                         = "ami-0c1ac8a41498c1a9c"
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.Public-Subnet-1.id
#   vpc_security_group_ids      = [aws_security_group.SG.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.KP.key_name

#   tags = { Name = "backend-ami-host" }

# }

# Frontend AMI
data "aws_ami" "frontend" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["frontend-ami"]
  }
}

#Backend AMI
data "aws_ami" "backend" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["backend-ami"]
  }
}

#Frontend LT
resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt"
  image_id      = data.aws_ami.frontend.id       
  instance_type = "t3.micro"
  key_name      = aws_key_pair.KP.key_name

}

#Backend LT
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt"
  image_id      = data.aws_ami.backend.id         
  instance_type = "t3.micro"
  key_name      = aws_key_pair.KP.key_name

}

#ASG Frontend
resource "aws_autoscaling_group" "frontend_asg" {
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = [
    aws_subnet.Private-Subnet-1.id,
    aws_subnet.Private-Subnet-2.id,
  ]
  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.frontend-TG.arn]
  tag {
    key                 = "Name"
    value               = "frontend-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "backend_asg" {
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = [
    aws_subnet.Private-Subnet-1.id,
    aws_subnet.Private-Subnet-2.id,
  ]
  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.backend-TG.arn]
  tag {
    key                 = "Name"
    value               = "backend-asg-instance"
    propagate_at_launch = true
  }
}

#bastion-server
resource "aws_instance" "bastion" {
  ami                         = "ami-0c1ac8a41498c1a9c"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.Public-Subnet-1.id
  vpc_security_group_ids      = [aws_security_group.SG.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.KP.key_name

  tags = { Name = "bastion" }

}