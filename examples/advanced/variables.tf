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

variable "cidr" {
  description = "The CIDR ranges used for the deployed subnets"

  type = object({
    vpc     = string
    private = list(string)
    public  = list(string)
  })
}

variable "ec2_key_name" {
  description = "(Optional) EC2 Key Pair name, used for connecting to instances, primarily for debugging"
  type        = string
  default     = ""
}

variable "tags" {
  description = "(Optional) additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "postgres_master_user" {
  description = "(Optional) The master user for postgresql"
  type        = string
  default     = "root"
}
