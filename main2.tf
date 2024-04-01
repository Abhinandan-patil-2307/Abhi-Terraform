provider "aws" {
  region     = var.region_name
  access_key = var.access_key
  secret_key = var.secret_key
}
 
resource "aws_vpc" "customevpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "custom-vpc"
  }
}
 
resource "aws_internet_gateway" "custom-igw" {
  vpc_id = aws_vpc.customevpc.id
 
  tags = {
    Name = "custom-igw"
  }
}
 
resource "aws_subnet" "websubnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "us-east-1a"
  tags = {
    Name = "web-subnet"
  }
}
 
resource "aws_subnet" "appsubnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.16.0/20"
  availability_zone = "us-east-1b"
  tags = {
    Name = "app-subnet"
  }
}
 
resource "aws_subnet" "dbsubnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.32.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "db-subnet"
  }
}
 
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.customevpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom-igw.id
  }
    route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
 
   tags = {
    Name = "pub-rt"
  }
}
 
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.customevpc.id
    route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
 
   tags = {
    Name = "pvt-rt"
  }
}
 
resource "aws_route_table_association" "web-association" {
  subnet_id      = aws_subnet.websubnet.id
  route_table_id = aws_route_table.public-rt.id
}
 
resource "aws_route_table_association" "app-association" {
  subnet_id      = aws_subnet.appsubnet.id
  route_table_id = aws_route_table.private-rt.id
}
 
resource "aws_route_table_association" "db-association" {
  subnet_id      = aws_subnet.dbsubnet.id
  route_table_id = aws_route_table.private-rt.id
}
 
resource "aws_security_group" "web-sg" {
vpc_id = aws_vpc.customevpc.id
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
   egress {
   from_port = 0
   to_port = 0
   protocol = -1
   cidr_blocks = ["0.0.0.0/0"]
}
}
 
resource "aws_security_group" "app-sg" {
vpc_id = aws_vpc.customevpc.id
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["10.0.16.0/20"]
  }
   egress {
   from_port = 0
   to_port = 0
   protocol = -1
   cidr_blocks = ["0.0.0.0/0"]
}
}
 
resource "aws_security_group" "db-sg" {
vpc_id = aws_vpc.customevpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.32.0/24"]
  }
   egress {
   from_port = 0
   to_port = 0
   protocol = -1
   cidr_blocks = ["0.0.0.0/0"]
}
}
 
resource "aws_instance" "webec2" {
 associate_public_ip_address = true 
  ami               = "ami-0440d3b780d96b29d"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  key_name = "tf-key-pair"
  subnet_id = aws_subnet.websubnet.id
  tags = {
    Name = "web-inst"
  }
 }
 
resource "aws_instance" "appec2" {
  ami               = "ami-0440d3b780d96b29d"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.app-sg.id]
  key_name = "tf-key-pair"
  subnet_id = aws_subnet.appsubnet.id
  tags = {
    Name = "app-inst"
  }
 }
 
resource "aws_db_instance" "rds" {
  allocated_storage = 10
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  identifier = "mydb"
  username = "root"
  password = "Pass1234"
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  db_subnet_group_name = aws_db_subnet_group.mydbsubgp.id
  skip_final_snapshot = true
}
 
resource "aws_db_subnet_group" "mydbsubgp" {
  name       = "mydbsubsp"
  subnet_ids = [aws_subnet.dbsubnet.id, aws_subnet.appsubnet.id]
 
  tags = {
    Name = "My DB subnet group"
  }
}
 
resource "aws_key_pair" "tf-key-pair" {
  key_name   = "tf-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tf-key-pair"
}
