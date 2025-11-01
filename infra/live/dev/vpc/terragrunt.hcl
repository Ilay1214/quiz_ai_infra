terragrunt {
    source = "${get_repo_root()}/infra/modules/vpc"
}
include "root" {
    path = find_in_parent_folders()
}


locals {
    env ="dev"
    tags = {
     project = "project-circle-assistant"
     environment = local.env
     
    }
}

inputs = {
    vpc_cidr = "10.0.0.0/16"
    num_of_azs = 2
    project_name = "project-circle-assistant"
    environment = "dev"
}