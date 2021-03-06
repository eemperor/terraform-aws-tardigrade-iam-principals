provider aws {
  region = "us-east-1"
}

module "policies" {
  source = "../../modules/policies/"

  providers = {
    aws = aws
  }

  policies         = [for policy in local.policies : merge(local.policy_base, policy)]
  policy_documents = [for policy_document in local.policy_documents : merge(local.policy_document_base, policy_document)]
  policy_names     = local.policies[*].name
}

module "users" {
  source = "../../modules/users/"

  providers = {
    aws = aws
  }

  policy_arns = local.policy_arns
  users       = [for user in local.users : merge(local.user_base, user)]
}

module "create_groups" {
  source = "../../modules/groups/"

  providers = {
    aws = aws
  }

  groups          = [for group in local.groups : merge(local.group_base, group)]
  inline_policies = local.group_inline_policies
  policy_arns     = [for policy in module.policies.policies : policy.arn]
  user_names      = local.user_names
}

resource "random_string" "this" {
  length  = 6
  upper   = false
  special = false
  number  = false
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "terraform_remote_state" "prereq" {
  backend = "local"
  config = {
    path = "prereq/terraform.tfstate"
  }
}

locals {
  test_id = length(data.terraform_remote_state.prereq.outputs) > 0 ? data.terraform_remote_state.prereq.outputs.random_string.result : ""

  policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/tardigrade-alpha-${local.test_id}",
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/tardigrade/tardigrade-beta-${local.test_id}",
  ]

  user_names = [
    "tardigrade-user-alpha-${local.test_id}",
    "tardigrade-user-beta-${local.test_id}",
  ]

  inline_policies = [
    {
      name     = "tardigrade-alpha-${local.test_id}"
      template = "policies/template.json"
    },
    {
      name     = "tardigrade-beta-${local.test_id}"
      template = "policies/template.json"
    },
  ]

  user_base = {
    policy_arns          = []
    inline_policy_names  = []
    access_keys          = []
    force_destroy        = null
    path                 = null
    permissions_boundary = null
    tags                 = {}
  }

  users = [
    {
      name = "tardigrade-user-alpha-${local.test_id}"
    },
    {
      name = "tardigrade-user-beta-${local.test_id}"
    },
  ]

  policy_base = {
    path        = null
    description = null
  }

  policy_document_base = {
    template_vars = local.template_vars_base
    template_paths = [
      "${path.module}/../templates/"
    ]
  }

  template_vars_base = {
    account_id    = data.aws_caller_identity.current.account_id
    partition     = data.aws_partition.current.partition
    region        = data.aws_region.current.name
    random_string = random_string.this.result
  }

  policies = [
    {
      description = "test"
      name        = "tardigrade-alpha-${local.test_id}"
    },
    {
      name = "tardigrade-beta-${local.test_id}"
      path = "/tardigrade/"
    },
  ]

  policy_documents = [
    {
      name     = "tardigrade-alpha-${local.test_id}"
      template = "policies/template.json"
    },
    {
      name     = "tardigrade-beta-${local.test_id}"
      template = "policies/template.json"
    },
  ]

  group_base = {
    inline_policy_names = []
    path                = null
    policy_arns         = []
    user_names          = []
  }

  group_inline_policies = [
    {
      name            = "tardigrade-group-alpha-${local.test_id}"
      inline_policies = [for policy in local.inline_policies : merge(local.policy_base, local.policy_document_base, policy)]
    },
    {
      name            = "tardigrade-group-beta-${local.test_id}"
      inline_policies = [for policy in local.inline_policies : merge(local.policy_base, local.policy_document_base, policy)]
    },
    {
      name            = "tardigrade-group-delta-${local.test_id}"
      inline_policies = [for policy in local.inline_policies : merge(local.policy_base, local.policy_document_base, policy)]
    },
  ]

  groups = [
    {
      name                = "tardigrade-group-alpha-${local.test_id}"
      inline_policy_names = local.inline_policies[*].name
      policy_arns         = local.policy_arns
      path                = "/tardigrade/alpha/"
      user_names          = [for user in module.users.users : user.name]
    },
    {
      name                = "tardigrade-group-beta-${local.test_id}"
      inline_policy_names = local.inline_policies[*].name
      policy_arns         = local.policy_arns
      user_names          = [for user in module.users.users : user.name if user.name == "tardigrade-user-beta-${local.test_id}"]
    },
    {
      name        = "tardigrade-group-chi-${local.test_id}"
      policy_arns = local.policy_arns
    },
    {
      name                = "tardigrade-group-delta-${local.test_id}"
      inline_policy_names = local.inline_policies[*].name
    },
    {
      name = "tardigrade-group-epsilon-${local.test_id}"
    },
  ]
}

output "create_groups" {
  value = module.create_groups
}
