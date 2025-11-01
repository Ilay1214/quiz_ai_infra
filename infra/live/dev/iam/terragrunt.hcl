terraform {
    source = "${get_repo_root()}/infra/modules/iam"
}


include "root" {
    path = find_in_parent_folders()
    expose = true
}

locals {
    region = include.root.locals.aws_region
    account_id = include.root.locals.aws_account_id
}

inputs = {
    environment = include.root.locals.environment
    github_repo = include.root.locals.github_repo

    allowed_secret_arns = [
        "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:*"
    ]
}
