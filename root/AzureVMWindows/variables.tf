variable "resourceaccountWin" {
  type    = string
  default = "RG-IS"
}

variable "Location" {
  type    = string
  default = "francecentrale"
}

variable "username" {
  type    = string
  default = "azureadmin"
}

variable "prefix" {
  type        = string
  default     = "win-vm-iis"
  description = "Prefix of the resource name"
}