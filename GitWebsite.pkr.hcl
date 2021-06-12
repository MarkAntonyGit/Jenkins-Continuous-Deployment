variable "access_key" {
  type    = string
  default = "your access key"
}

variable "secret_key" {
  type    = string
  default = "your seceret key"
}
    
variable "ami" {
  type    = string
  default = "desire ami id"    
}

variable "type" {
  type    = string
  default = "desired instance type" 
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "Git-Website" {
  access_key    = "${var.access_key}"
  ami_name      = "packer-Git-Website ${local.timestamp}"
  instance_type = "${var.type}"
  region        = "ap-south-1"
  secret_key    = "${var.secret_key}"
  source_ami    = "${var.ami}"
  ssh_username  = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.Git-Website"]
  
  provisioner "shell" {
    script = "/var/Jenkins-Continuous-Deployment/Git-Script.sh"
  }

  post-processor "shell-local" {
    inline = ["echo AMI Created"]
  }
}
