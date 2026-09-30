output "vpc_id" {
  value = aws_vpc.ykVPC.id
}

output "instance_id" {
  value = aws_instance.test_server.id
}

output "instance_public_ip" {
  value = aws_instance.test_server.public_ip
}

output "s3_secure_bucket_name" {
  value = aws_s3_bucket.secure_logs_bucket.id
}