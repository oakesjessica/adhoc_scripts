output "bastion-public-ip" {
  value = aws_instance.bastion-instance.public_ip
}
