provider "aws" {
  access_key = "AKIAJCEWH7DABWX6PQHA"
  secret_key = "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"
  region     = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block      = "10.88.0.0/16"
  instance_tenancy = "default"

  tags {
    Name = "main_Kubernettes"
    Type = "kubernettes_cluster"
  }
}

resource "aws_subnet" "kube_subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.88.16.0/24"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id = "${aws_vpc.main.id}"

  # Not typically recommended.. but I know what ports will be opened on the endpoint!
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "allow_all"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "main_Kubernettes_igw"
    Type = "Cluster_VPC"
  }
}

resource "aws_route_table" "Kube_Routes" {
  vpc_id            = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

# Associate Route table with the Subnet.
resource "aws_route_table_association" "Route_Table_Association" {
    subnet_id      = "${aws_subnet.kube_subnet.id}"
    route_table_id = "${aws_route_table.Kube_Routes.id}"
}

# Request a spot instance at $0.03
resource "aws_spot_instance_request" "knode1" {
  ami                 = "ami-07585467"
  spot_price          = "0.008"
  spot_type           = "persistent"
  instance_type       = "t3.small"
  key_name            = "tewest"
  subnet_id           = "${aws_subnet.kube_subnet.id}"
  associate_public_ip_address = "True"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  depends_on          = ["aws_internet_gateway.gw"]
  tags {
    Name = "master_node"
  }

  user_data = "${file("${path.module}/data/install.sh")}"

}

resource "aws_spot_instance_request" "knode2" {
  ami                 = "ami-07585467"
  spot_price          = "0.008"
  spot_type           = "persistent"
  instance_type       = "t3.small"
  key_name            = "tewest"
  subnet_id           = "${aws_subnet.kube_subnet.id}"
  associate_public_ip_address = "True"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  depends_on          = ["aws_internet_gateway.gw"]
  tags {
    Name = "slave_node"
  }

  user_data = "${file("${path.module}/data/install.sh")}"

}

# Note, these two variables will throw errors if the IPs arent yet available.
# You will need to run ./terraform refresh to get the IP addresses. (Discussed in README).

output "knode1.ip" {
  depends_on = ["aws_spot_instance_request.knode1.id"]
  value = "${aws_spot_instance_request.knode1.public_ip}"
}

output "knode2.ip" {
  depends_on = ["aws_spot_instance_request.knode2.id"]
  value = "${aws_spot_instance_request.knode2.public_ip}"
}
