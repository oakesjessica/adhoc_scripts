variable "aws_credentials_file_path" {
  description = "AWS credentials file path"
}

variable "aws_credentials_profile" {
  default = "opi-saml"
  description = "AWS credentials profile"
}

variable "environment" {
  default = "sandbox"
  description = "Environment"
}

variable "tag_name_prefix" {
  default = "oakes"
  description = "Prefix for name tag"
}

variable "bastion-ami-id" {
  default = "ami-04505e74c0741db8d" # ubuntu for us-east-1
  description = "AMI ID for bastion instance"
}

variable "linux-ami-id" {
  default = "ami-08e4e35cccc6189f4"
}
