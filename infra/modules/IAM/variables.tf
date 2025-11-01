variable "allowed_secret_arns" {
    type = list(string)
}
variable "environment" {
    type = string
}
variable "github_repo" {
    type = string
}
locals {
  env_sanitized = join("", regexall("[0-9A-Za-z+=,.@-]", var.environment))
}
