provider "aws" {
    region = "ap-south-1"
    profile = "Naman"
    access_key="*******"
    secret_key="************"
}
#VPC
resource "aws_vpc" "taskvpc" {
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"
    enable_dns_hostnames = "true" 
tags = {
    Name = "taskvpc"
}
}

#PublicSubnet
resource "aws_subnet" "task_public_subnet" {
    vpc_id = aws_vpc.taskvpc.id
    cidr_block = "192.168.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = "true"
    depends_on = [
        aws_vpc.taskvpc,
    ]
    tags = {
        Name = "task_public_subnet"
    }
}

#PrivateSubnet
resource "aws_subnet" "task_private" {
    vpc_id = aws_vpc.taskvpc.id
    cidr_block = "192.168.1.0/24"
    availability_zone = "ap-south-1b"
    depends_on = [
        aws_vpc.taskvpc,
    ]
    tags = {
        Name = "task_private"
    }
}

#InternetGatewayForVPC
resource "aws_internet_gateway" "task_ig" {
    vpc_id = aws_vpc.taskvpc.id
    depends_on = [
        aws_vpc.taskvpc,
    ]
    tags = {
        Name = "task_ig"
    }
}

#RoutingTableForPublicSubnet
resource "aws_route_table" "task_rt" {
    vpc_id=aws_vpc.taskvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.task_ig.id
    }

    depends_on = [
        aws_vpc.taskvpc,
    ]
    tags = {
        Name = "task_rt"
    }
}

#AssociatingRouteTableWithPublicSubnet
resource "aws_route_table_association" "task_assoc" {
    subnet_id = aws_subnet.task_public_subnet.id
    route_table_id = aws_route_table.task_rt.id
    depends_on = [
        aws_subnet.task_public_subnet,
    ]
}

#ElasticIP
resource "aws_eip" "task_eip" {
  vpc = true
}

 #NATGateway
resource "aws_nat_gateway" "task_nat" {
  depends_on = [
    aws_eip.task_eip
  ]

  #AllocationOfEIPtoNATGateway
  allocation_id = aws_eip.task_eip.id
  
  #AssociatingToPublicSubnet
  subnet_id = aws_subnet.task_public_subnet.id
  tags = {
    Name = "Nat-Gateway_Project"
  }
}
#RoutingTableForNATGateway
resource "aws_route_table" "task_nat_rt" {
  depends_on = [
    aws_nat_gateway.task_nat
  ]

  vpc_id = aws_vpc.taskvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.task_nat.id
  }

  tags = {
    Name = "Route Table for NAT Gateway"
  }

}

#AssociationOfNATGatewayToPrivateSubnet
resource "aws_route_table_association" "NAT-gateway-association" {
  depends_on = [ aws_route_table.task_nat_rt ]
  subnet_id = aws_subnet.task_private.id
  route_table_id = aws_route_table.task_nat_rt.id
}

#SecurityGroupForWordPress
resource "aws_security_group" "wordpress_sg" {
    name = "wordpress_sg"
    description = "allow ssh and http to wordpress instance"
    vpc_id = aws_vpc.taskvpc.id

    ingress {
        description = "for ssh"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        description = "for http"
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
    depends_on = [
        aws_vpc.taskvpc,
        ]
    tags = {
            Name = "wordpress_sg"
        }
}

#SecurityGroupForMySQL
resource "aws_security_group" "mysql_sg"{
    name = "mysql_sg"
    description = "allow wordpress to access mysql instance"
    vpc_id = aws_vpc.taskvpc.id

    ingress {
        description = "to allow wordpress instance on mysql port"
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [aws_security_group.wordpress_sg.id]
    }
        ingress {
        description = "SSH by Wordpress Instance for maintenance tasks"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.wordpress_sg.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks=["0.0.0.0/0"]
    }
    depends_on = [
        aws_vpc.taskvpc,
        aws_security_group.wordpress_sg,
    ]
    tags = {
        Name = "mysql_sg"
    }
}

/*#SecurityGroupForBastionHost
resource "aws_security_group" "bastion-sg" {

  depends_on = [
    aws_vpc.taskvpc,
    aws_subnet.task_public_subnet,
    aws_subnet.task_private
  ]

  description = "MySQL Access only from the Webserver Instances!"
  name = "bastion-host-sg"
  vpc_id = aws_vpc.taskvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outisde Connectivity"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}*/

#WordPress Instance

resource "aws_instance" "wordpress_instance" {
  ami           = "ami-08675056b989a552a"
  instance_type = "t2.micro"
  key_name = "key1"
  vpc_security_group_ids = [ aws_security_group.wordpress_sg.id ]
  subnet_id = aws_subnet.task_public_subnet.id
  depends_on = [ aws_subnet.task_public_subnet ]

  tags = {
    Name = "WordPress"
  }
}

#MySQL Instance

resource "aws_instance" "mysql_instance" {
  ami           = "ami-028e055cfe9eec3c3"
  instance_type = "t2.micro"
  key_name = "key1"
  vpc_security_group_ids = [ aws_security_group.mysql_sg.id ]
  subnet_id = aws_subnet.task_private.id
  depends_on = [ aws_subnet.task_private,aws_security_group.mysql_sg ]

  tags = {
    Name = "MySQL"
  }
}

/*#BastionHost
resource "aws_instance" "bastion_instance" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.bastion-sg.id ]
  subnet_id = aws_subnet.task_private.id
  depends_on = [ aws_instance.wordpress_instance, aws_instance.mysql_instance ]

  tags = {
    Name = "BastionHost"
  }
}*/
