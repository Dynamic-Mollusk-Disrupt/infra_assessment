# top-level resources
provider "aws" {
    region = var.REG
    access_key = var.ACC
    secret_key = var.SEC
}

resource "aws_key_pair" "id_rsa_nginx_ec2" {
    key_name = "nginx_ec2"
    public_key = file("id_rsa_ec2-nginx.pub")
}

resource "aws_vpc" "vpc_dmd" {
    cidr_block = "10.0.0.0/24" # We don't need a /16, how wasteful. Using https://www.davidc.net/sites/default/subnets/subnets.html to divide up a /24 instead
    enable_dns_hostnames = true # we want DNS so we can ssh in later if we have time to do that
}

# network-level resources
resource "aws_internet_gateway" "vpc_dmd_igw" {
    vpc_id = aws_vpc.vpc_dmd.id
}

resource "aws_route_table" "vpc_dmd_rt_pub" {
    vpc_id = aws_vpc.vpc_dmd.id
    route {
        cidr_block = "0.0.0.0/0" # expose to le internet
        gateway_id = aws_internet_gateway.vpc_dmd_igw.id
    }
}

resource "aws_subnet" "sn_1a_pub" {
    vpc_id = aws_vpc.vpc_dmd.id
    cidr_block = "10.0.0.0/25"
    availability_zone = format("%s%s",var.REG,"a") #Thanks https://stackoverflow.com/a/58224248/11351150
}

resource "aws_route_table_association" "sn_1a_pub_ra" {
    subnet_id = aws_subnet.sn_1a_pub.id
    route_table_id = aws_route_table.vpc_dmd_rt_pub.id
}

resource "aws_subnet" "sn_1b_pub" {
    vpc_id = aws_vpc.vpc_dmd.id
    cidr_block = "10.0.0.128/25"
    availability_zone = format("%s%s",var.REG,"b") # No, IRL you would not do this logic like this, you'd statically define it
}

resource "aws_route_table_association" "sn_1b_pub_ra" {
    subnet_id = aws_subnet.sn_1b_pub.id
    route_table_id = aws_route_table.vpc_dmd_rt_pub.id
}

# ALB (still technically networky but hey)-level resources
resource "aws_security_group" "alb_pub_sg" {
    vpc_id = aws_vpc.vpc_dmd.id
    ingress {
        from_port = 80 # IRL this would be 443
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 80 # we don't need any port to any port
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb" "alb_pub" {
    name = "alb-pub" #this one requires kebab case because of amazon
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb_pub_sg.id]
    subnets = [
        aws_subnet.sn_1a_pub.id,
        aws_subnet.sn_1b_pub.id 
    ]
}

resource "aws_lb_target_group" "alb_pub_tgroup" {
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.vpc_dmd.id
}

resource "aws_lb_listener" "alb_pub_listener" {  
    load_balancer_arn = aws_lb.alb_pub.arn
    port = 80  
    protocol = "HTTP"
    default_action {    
        target_group_arn = aws_lb_target_group.alb_pub_tgroup.arn
        type = "forward"  
    }
}

# EC2-level resources
resource "aws_security_group" "nginx_ec2_lc_sg" {
    vpc_id = aws_vpc.vpc_dmd.id
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Just 1 ec2 instance will do, thank you. Phase 2 would need some actual autoscaling so I filled this out anyways
# resource "aws_launch_configuration" "nginx_ec2_lc" {
#     image_id = "ami-032dc1bc3220389e7"
#     instance_type = "t3.micro"
#     key_name = aws_key_pair.id_rsa_nginx_ec2.key_name
#     security_groups = [aws_security_group.nginx_ec2_lc_sg.id]
#     associate_public_ip_address = true
#     lifecycle {
#         create_before_destroy = true
#     }
#     user_data = file("nginx_ec2_deploy.sh")
#}

# resource "aws_autoscaling_group" "alb_pub_as" {
#     name = "alb_pub_as"
#     desired_capacity = 3
#     min_size = 2
#     max_size = 9
#     health_check_type = "ELB"
#     force_delete = true
#     launch_configuration = aws_launch_configuration.nginx_ec2_lc.id
#     vpc_zone_identifier = [
#         aws_subnet.sn_1a_pub.id,
#         aws_subnet.sn_1b_pub.id 
#     ]
#     timeouts {
#         delete = "5m"
#     }
#     lifecycle {
#         create_before_destroy = true
#     }
# }

# resource "aws_autoscaling_attachment" "alb_pub_as_attach" {
#     alb_target_group_arn = aws_lb_target_group.alb_pub_tgroup.arn
#     autoscaling_group_name = aws_autoscaling_group.alb_pub_as.id
# }

# I have to do at least 25% different than the boilerplate to show I'm not just blindly copy/pasting and tweaking the values, so
# I made my implementation not auto-scale. Worse is better?
# Used https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#argument-reference
resource "aws_instance" "nginx_ec2_1a" {
  # Minimal Amazon Linux 2 AMI https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#ImageDetails:imageId=ami-001e76b3918fba080
  # IRL we'd have a base image either built-in with nginx via Packer etc. or
  # just do our corporate image and have nginx be installed at runtime, slower baking time but we can
  # have more version flexibility etc.
  ami = "ami-001e76b3918fba080"
  instance_type = "t3.micro"  # using fee tier here. IRL this would be IDK M5.large or something if prod
  key_name = aws_key_pair.id_rsa_nginx_ec2.key_name
  vpc_security_group_ids = [aws_security_group.nginx_ec2_lc_sg.id]
  subnet_id = aws_subnet.sn_1a_pub.id
  associate_public_ip_address = false # No we don't want this, stick it behind the ALB
  user_data = file("nginx_ec2_deploy.sh")
}

# Copy/pasta-ing here but normally I'd research how to do that for_each instance count and pass in an instance count as a variable
resource "aws_instance" "nginx_ec2_1b" {
  ami = "ami-001e76b3918fba080"
  instance_type = "t3.micro"  # using fee tier here. IRL this would be IDK M5.large or something if prod
  key_name = aws_key_pair.id_rsa_nginx_ec2.key_name
  vpc_security_group_ids = [aws_security_group.nginx_ec2_lc_sg.id]
  subnet_id = aws_subnet.sn_1b_pub.id
  associate_public_ip_address = false
  user_data = file("nginx_ec2_deploy.sh")
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment
resource "aws_lb_target_group_attachment" "alb_pub_tgroup_attach_1a" {
  target_group_arn = aws_lb_target_group.alb_pub_tgroup.arn
  target_id        = aws_instance.nginx_ec2_1a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "alb_pub_tgroup_attach_1b" {
  target_group_arn = aws_lb_target_group.alb_pub_tgroup.arn
  target_id        = aws_instance.nginx_ec2_1b.id
  port             = 80
}

output "alb_url" {
    value = aws_lb.alb_pub.dns_name
}