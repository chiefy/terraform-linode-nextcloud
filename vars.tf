//
// Required
//
variable "ssh_key_file" {}
variable "linode_api_key" {}

//
// Optional
//
variable "root_password" {
    default = "duolctxen"
}

variable "linode_region" {
    default = "Newark, NJ, USA"
}

variable "linode_size" {
    default = 1024
}

