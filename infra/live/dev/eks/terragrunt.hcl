terraform {
    source = "${get_repo_root()}/infra/modules/eks"
}
include "root" {
    path = find_in_parent_folders()
    expose = true
}

dependency "vpc" {
    config_path = "../vpc"
    mock_outputs = {
        vpc_id          = "vpc-000000"
        private_subnets = ["subnet-0000001", "subnet-0000002"]
    }
    mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
dependency "iam" {
    config_path = "../iam"
    mock_outputs = {
        eso_policy_arn = "arn:aws:iam::111122223333:policy/mock-eso"
    }
    mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

locals {
    env = "dev"
    tags = {
     project = include.root.locals.project
     environment = local.env
     
    }
    is_windows = length(regexall("(?i)windows", get_env("OS", ""))) > 0
    my_ip = local.is_windows ? chomp(run_cmd(
            "powershell", "-NoProfile", "-Command",
            "(Invoke-WebRequest -UseBasicParsing 'https://checkip.amazonaws.com').Content.Trim()"
        )) : chomp(run_cmd(
            "bash", "-lc",
            "curl -s https://checkip.amazonaws.com"
        ))

    api_public_cidrs = ["${local.my_ip}/32"]
}

inputs = {
    vpc_id = dependency.vpc.outputs.vpc_id
    private_subnets = dependency.vpc.outputs.private_subnets
    api_public_cidrs = local.api_public_cidrs
    eso_policy_arn = dependency.iam.outputs.eso_policy_arn
    environment = local.env
    kubernetes_version = "1.29"

    #node group settings:
    instance_types = ["t3.medium"]
    min_size = 1
    max_size = 2
    desired_size = 1
    capacity_type = "SPOT"
    ami_type = "AL2_x86_64"
}