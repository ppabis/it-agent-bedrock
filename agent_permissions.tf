data "aws_iam_policy_document" "agent_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent_role" {
  name               = "ticketagent-agent-role"
  assume_role_policy = data.aws_iam_policy_document.agent_assume_role.json
}

data "aws_iam_policy_document" "agent_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModel*",
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
      "bedrock:ListTagsForResource",
      "bedrock:GetKnowledgeBase",
      "bedrock:ListKnowledgeBases",
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate",
      "bedrock:ApplyGuardrail",
      "bedrock:GetGuardrail"
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.ticket_lambda.arn]
  }
}

resource "aws_iam_role_policy" "agent_policy" {
  name   = "ticketagent-agent-policy"
  role   = aws_iam_role.agent_role.id
  policy = data.aws_iam_policy_document.agent_policy.json
}