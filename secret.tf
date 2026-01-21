resource "aws_secretsmanager_secret" "confluence" {
  name                    = "confluence"
  description             = "Confluence credentials"
  recovery_window_in_days = 7
}

variable "confluence_username" {
  type        = string
  description = "Confluence username (admin email address)"
}

variable "confluence_password" {
  type        = string
  description = "Confluence password (API token)"
}

###
# Your secret must contain the admin user email address of the Atlassian account as the username and a Confluence API
# token in place of a password. For information about how to create a Confluence API token, see Manage API tokens for
# your Atlassian account on the Atlassian website.
###
resource "aws_secretsmanager_secret_version" "confluence" {
  secret_id = aws_secretsmanager_secret.confluence.id
  secret_string = jsonencode({
    username = var.confluence_username
    password = var.confluence_password
  })
  lifecycle { ignore_changes = [ secret_string ] }
}