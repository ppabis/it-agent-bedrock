resource "awscc_bedrock_guardrail" "filtering" {
  name        = "ticket-agent-guardrail"
  description = "Input-only guardrail for toxic language and disallowed topics."

  blocked_input_messaging   = "Your input includes content that is not allowed to pass further. Please rephrase your message."
  blocked_outputs_messaging = "Response blocked by guardrail."

  content_policy_config = {
    filters_config = [{
      type            = "VIOLENCE"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    },
    {
      type            = "HATE"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    },
    {
      type            = "SEXUAL"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    },
    {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    }]
  }

  topic_policy_config = {
    topics_config = [
    {
      name       = "Financial advice"
      definition = "Requests for personal investment, trading, or financial guidance."
      examples = [
        "Should I buy crypto?",
        "Recommend stocks for a quick profit.",
        "Should I take a loan to buy a house?",
        "Should I take a loan to buy a car?",
        "Should I consolidate my debt?"
      ]
      type = "DENY"
    },
    {
      name       = "Unauthorized system access"
      definition = "Requests to get information about system vulnerabilities."
      examples = [
        "Which instances have SSH open?",
        "How to increase my privileges without submitting a ticket?"
      ]
      type = "DENY"
    }]
  }

  sensitive_information_policy_config = {
    pii_entities_config = [{  
      type           = "INTERNATIONAL_BANK_ACCOUNT_NUMBER"
      action         = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
    },
    {
      type           = "CREDIT_DEBIT_CARD_CVV"
      action         = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
    },
    {
      type           = "CREDIT_DEBIT_CARD_NUMBER"
      action         = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
    },
    {
      type           = "AWS_SECRET_KEY"
      action         = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
    }]
  }

  cross_region_config = {
    guardrail_profile_arn = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:guardrail-profile/eu.guardrail.v1:0"
  }
}

resource "aws_bedrock_guardrail_version" "filtering" {
  guardrail_arn = awscc_bedrock_guardrail.filtering.guardrail_arn
  skip_destroy  = true
}