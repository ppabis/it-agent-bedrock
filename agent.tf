data "aws_bedrock_inference_profiles" "agent_profile" {
  type = "SYSTEM_DEFINED"
}

locals {
  inference_profile_arn = [
    for profile in data.aws_bedrock_inference_profiles.agent_profile.inference_profile_summaries
    : profile.inference_profile_arn
    if strcontains(profile.inference_profile_name, "Nova 2 Lite")
    && strcontains(profile.inference_profile_name, "EU")
  ][0]
  prompts = yamldecode(file("prompts.yaml"))
}


resource "aws_bedrockagent_agent" "ticketagent" {
  agent_name              = "ticketagent"
  foundation_model        = local.inference_profile_arn
  agent_resource_role_arn = aws_iam_role.agent_role.arn
  depends_on              = [aws_bedrockagent_knowledge_base.confluence]
  prepare_agent           = true
  instruction             = local.prompts.agent_prompt

  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail_version.filtering.guardrail_arn
    guardrail_version    = aws_bedrock_guardrail_version.filtering.version
  }
}

resource "aws_bedrockagent_agent_action_group" "jira_tickets" {
  agent_id           = aws_bedrockagent_agent.ticketagent.id
  agent_version      = "DRAFT"
  action_group_state = "ENABLED"
  action_group_name  = "jira_tickets"
  action_group_executor {
    lambda = aws_lambda_function.ticket_lambda.arn
  }
  api_schema {
    payload = file("lambdas/tool_schema.json")
  }
}

resource "aws_bedrockagent_agent_action_group" "user_input" {
  agent_id                      = aws_bedrockagent_agent.ticketagent.id
  agent_version                 = "DRAFT"
  action_group_name             = "AskUserAction"
  action_group_state            = "ENABLED"
  parent_action_group_signature = "AMAZON.UserInput"
}

resource "aws_bedrockagent_agent_knowledge_base_association" "confluence" {
  agent_id             = aws_bedrockagent_agent.ticketagent.id
  knowledge_base_id    = aws_bedrockagent_knowledge_base.confluence.id
  knowledge_base_state = "ENABLED"
  depends_on           = [aws_bedrockagent_agent.ticketagent, aws_bedrockagent_knowledge_base.confluence]
  description          = local.prompts.knowledge_base_description
}

resource "aws_bedrockagent_agent_alias" "production" {
  agent_id         = aws_bedrockagent_agent.ticketagent.id
  agent_alias_name = "ticketagent-production"
  depends_on = [
    aws_bedrockagent_agent_knowledge_base_association.confluence,
    aws_bedrockagent_agent_action_group.jira_tickets,
    aws_bedrockagent_agent_action_group.user_input
  ]
}

output "agent_alias" {
  value = aws_bedrockagent_agent_alias.production.agent_alias_arn
}