variable "region" {
  description = "The name of an AWS region"
  type        = string
}

variable "root_domain" {
  description = "Domain name to use for Concourse. Used to lookup existing Hosted Zone"
  type        = string
}

variable "concourse_credential" {
  description = "Usernames and passwords for deployment of Concourse"
  type = object({
    web = object({
      username = string
      password = string
    })
    db = object({
      username = string
      password = string
    })
  })
}
