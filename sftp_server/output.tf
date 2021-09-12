resource "aws_ssm_parameter" "sftp_hostname" {
  name  = "/sftp/${var.server_name}/hostname"
  type  = "String"
  value = aws_transfer_server.this.endpoint
}