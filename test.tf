provider "aws" {
    region     = "eu-central-1"
}

data "aws_availability_zones" "available" {}

data "aws_ami" "latest_amazon_linux" {
    owners = [ "amazon" ]
    most_recent = true

    filter {
        name   = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc_test.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_gw.id
}

resource "aws_internet_gateway" "test_gw" {
    vpc_id = aws_vpc.vpc_test.id
    tags = {
        Name = "test_gw"
    }
}

resource "aws_vpc" "vpc_test" {
    cidr_block            = "10.0.0.0/16"
    enable_dns_support    = "true"
    enable_dns_hostnames  = "true"
    tags = {
       Name = "vpc_test"
    }
}

resource "aws_subnet" "public-sn-1" {
    vpc_id            = aws_vpc.vpc_test.id
    availability_zone = data.aws_availability_zones.available.names[0]
    cidr_block        = "10.0.1.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "public-sn-1"
    }
}

resource "aws_subnet" "public-sn-2" {
    vpc_id            = aws_vpc.vpc_test.id
    availability_zone = data.aws_availability_zones.available.names[1]
    cidr_block        = "10.0.2.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "public-sn-2"
    }
}

resource "aws_subnet" "private-sn-1" {
    vpc_id            = aws_vpc.vpc_test.id
    availability_zone = data.aws_availability_zones.available.names[0]
    cidr_block        = "10.0.3.0/24"
    tags = {
        Name = "private-sn-1"
    }
}

resource "aws_subnet" "private-sn-2" {
    vpc_id            = aws_vpc.vpc_test.id
    availability_zone = data.aws_availability_zones.available.names[1]
    cidr_block        = "10.0.4.0/24"
    tags = {
        Name = "private-sn-2"
    }
}

resource "aws_key_pair" "key_test" {
  key_name   = "key_test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDeiUMwDPpP/AWV6rhiVfirdEcelMgCMkr4AjHNq+ucb0DlDcBTMbwPf4/FoJInrU3mttbsPfLkq39WyYvOk55Sv2e7XH4zL4pbWLai4CBUiEySjPe4jb3HpsFLoD2i9KWKNTwY5+2NOi5gQwUCTpBxGMHLyTu8+R2pQMIiCqSb687CkZSMqVeYN9jldjr80MSK1jJfKIK2THHuVhsBS9lb4o7GWvRX1a+1RIqDmGleHqewgYwYK3E8IdYpnBM01UweA1GPi+zFrbbUAVX5VMkGxL4WmETiQAWHz3LEpLTrjBLKYxr6pOE1Saxnlyxyz3pjxyrh3e4mCTYz8YnUGqaH root@DESKTOP-H8NR2I8"
  }

resource "aws_security_group" "web-public-sg" {
  name = "web-public-sg"
  vpc_id = aws_vpc.vpc_test.id
  dynamic "ingress" {
    for_each = ["80", "443", "22"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "web-public-sg"
  }
}

resource "aws_security_group" "web-private-sg" {
  name = "web-private-sg"
  vpc_id = aws_vpc.vpc_test.id
  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "web-private-sg"
  }
}

resource "aws_security_group" "psql-private-sg" {
  name = "psql-private-sg"
  vpc_id = aws_vpc.vpc_test.id
  dynamic "ingress" {
    for_each = ["5432"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "psql-private-sg"
  }
}

resource "aws_eip" "nat" {
  vpc      = true
}
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private-sn-1.id
}

resource "aws_instance" "webserver-public" {
    ami                    = data.aws_ami.latest_amazon_linux.id
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.web-public-sg.id]
    availability_zone      = data.aws_availability_zones.available.names[0]
    subnet_id              = aws_subnet.public-sn-1.id
    user_data = templatefile("user_data.tpl", {
      webserver-private-ip = aws_instance.webserver-private.private_ip
      })
    tags = {
      Name  = "webserver-public"
    }
    key_name = aws_key_pair.key_test.key_name
}

resource "aws_instance" "webserver-private" {
    ami                    = data.aws_ami.latest_amazon_linux.id
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.web-private-sg.id]
    availability_zone      = data.aws_availability_zones.available.names[0]
    subnet_id              = aws_subnet.public-sn-1.id
    user_data              = file("user_data_private.tpl")
    # user_data = templatefile("user_data.tpl", {
    #  db-dns = aws_db_instance.psql-private.address
    #  })
    tags = {
        Name  = "webserver-private"
    }
}

resource "aws_db_subnet_group" "psql_db_subnet_group" {
    name       = "psql_db_subnet_group"
    subnet_ids = [aws_subnet.private-sn-1.id,aws_subnet.private-sn-2.id]
    tags = {
        Name = "psql_db_subnet_group"
    }
}

resource "aws_db_instance" "psql-private" {
    allocated_storage       = 20
    storage_type            = "gp2"
    engine                  = "postgres"
    instance_class          = "db.t2.micro"
    name                    = "mydb"
    username                = "admintest"
    password                = "admintest"
    backup_retention_period = 0
    skip_final_snapshot     = true
    apply_immediately       = true
    db_subnet_group_name    = aws_db_subnet_group.psql_db_subnet_group.id
    vpc_security_group_ids  = [aws_security_group.psql-private-sg.id]
    tags = {
        Name  = "psql-private"
    }  
}
resource "aws_s3_bucket" "my-test-s3-bucket-for-numbers" {
    bucket = "my-test-s3-bucket-for-numbers-51243"
    acl    = "private"
    tags   = {
       Name  = "my-test-s3-bucket-for-numbers"
    }
}

# output "web_url" {
#   value = aws_db_instance.psql-private.address
# }

