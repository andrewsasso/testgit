provider "aws" {
  region = "us-east-1"
}

#Crea nuevo VPC llamado test_vpc
resource "aws_vpc" "test_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "test_vpc"
  }
}
#crea subnet privada
resource "aws_subnet" "my_subnet1_priv" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "my_subnet1_priv"
  }
}
#crea subnet publica
resource "aws_subnet" "my_subnet2_pub" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "my_subnet2_pub"
  }
}

#crea elastic ip
resource "aws_eip" "eip" {
  vpc = true
}

#crea internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

#crea Nat gateway y lo asocia la pub
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.my_subnet2_pub.id

  tags = {
    Name = "nat_gateway"
  }
}

#crea tablas de ruteo para ig y red publica
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}
#crea tablas de ruteo para el nat y la red privada (anteriormente asociada a la publica)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private_rt"
  }
}

#asocia las tablas anteriormente mencionadas
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.my_subnet2_pub.id
  route_table_id = aws_route_table.public_rt.id
}
#asocia las tablas anteriormente mencionadas
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.my_subnet1_priv.id
  route_table_id = aws_route_table.private_rt.id
}

#hasta este punto testeado, funciona al 100%

#Agregando recursos

#se agregan 1 instancias 1 a cada subnet

resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Security group for instance in public subnet"

  vpc_id = aws_vpc.test_vpc.id  

  // Reglas de entrada
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir SSH desde cualquier IP
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir HTTP desde cualquier IP
  }

  // Reglas de salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Permitir todo el tráfico de salida
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance_sg"
  }
}

resource "aws_instance" "istea_ec2_public" {

    ami = "ami-04e5276ebb8451442"
    instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_subnet2_pub.id
  associate_public_ip_address = true  # Asignar IP pública
  key_name      = "key2"  # Nombre del par de claves
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  tags = {
    Name = "instancia_public"
  }
}

resource "aws_instance" "istea_ec2_private" {

   ami = "ami-04e5276ebb8451442"
   instance_type = "t2.micro"
   subnet_id = aws_subnet.my_subnet1_priv.id
   key_name      = "key2"
   vpc_security_group_ids = [aws_security_group.instance_sg.id]

    tags = {
        Name = "instancia_private"
    }

}


