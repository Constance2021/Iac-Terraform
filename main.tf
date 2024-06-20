#se connecter à aws
provider "aws"{
    access_key = "my-acces-key"
    secret_key = "my-secret-key"
    region = "us-east-1"
}
#inmporter le vpc
data "aws_vpc" "my-terraform" {
  id = "vpc_id"
}
#creer les subnets
resource "aws_subnet" "mypublic-subnet" {
    vpc_id = data.aws_vpc.my-terraform.id
    cidr_block = "50.10.199.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name=" public-subnet"
    }
}
resource "aws_subnet" " private-subnet" {
    vpc_id = data.aws_vpc.my-terraform.id
    cidr_block = "50.10.133.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name="myprivate-subnet"
    }
}
#import de elastic pour l'associer au natgatewy
data "aws_eip" "eip" {
    id="eip_id"
  
}
#creation du natgateway
resource "aws_nat_gateway" "natgat" {
    allocation_id = data.aws_eip.eip.id
    subnet_id = aws_subnet.mypublic-subnet.id
    tags = {
      Name="mynat-gateway"
    }
}
#creation de la route table du sbunet privé
resource "aws_route_table" "route" {
    vpc_id = data.aws_vpc.my-terraform.id
    route {
         cidr_block="0.0.0.0/0"
         gateway_id= aws_nat_gateway.natgat.id
    }
    tags = {
      Name="my-route-table"
    }
}
#assiociation de la route au subnet privé
resource "aws_route_table_association" "privateroute" {
    subnet_id = aws_subnet.myprivate-subnet.id
    route_table_id = aws_route_table.route.id
  
}
#génération de clé rsa pour la connexion ssh
resource "tls_private_key" "ssh" {
    algorithm = "RSA"
    rsa_bits = 4096
}
resource "aws_key_pair" "ssh" {
    key_name = "myKey"
    public_key = tls_private_key.ssh.public_key_openssh
}
output "ssh_private_key_pem" {
  value = tls_private_key.ssh.private_key_pem
  sensitive = true
}
output "ssh_public_key_pem" {
  value=tls_private_key.ssh.public_key_pem
  sensitive = true
}
#création de la security group
resource "aws_security_group" "securitygroup" {
    vpc_id = data.aws_vpc.my-terraform.id
    description = "my new security group for ssh connexion"
    ingress{
        cidr_blocks = ["0.0.0.0/0"]
        from_port = 22
        to_port = 22
        protocol = "tcp"
    }

    egress{
        cidr_blocks = ["0.0.0.0/0"]
        from_port = 0
        to_port = 0
        protocol = "-1"
    }

    tags={
        Name="my-sec-group"
    }


  
}
#creation des EC2
resource "aws_instance" "ec2instance1" {
    ami = "ami-08a0d1e16fc3f61ea"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.mypublic-subnet.id
    security_groups = [aws_security_group.securitygroup.id]
    key_name = aws_key_pair.ssh.key_name
    associate_public_ip_address = true
    tags = {
      Name="my-server1"
    }
    user_data = <<-EOF
                sudo apt update
                sudo apt install angular
                systemctl enable angular
                systemctl start angular
                EOF
}
output "server1" {
    value=aws_instance.ec2instance1.private_ip
  
}
resource "aws_instance" "ec2instance2" {
    ami = "ami-08a0d1e16fc3f61ea"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.myprivate-subnet.id
    security_groups = [aws_security_group.securitygroup.id]
    key_name = aws_key_pair.ssh.key_name
    tags = {
      Name="my-server2"
    }
    user_data = <<-EOF
                sudo apt update
                sudo apt install python
                systemctl enable python
                systemctl start python
                EOF
}
output "server2" {
    value=aws_instance.ec2instance2.private_ip
  
}