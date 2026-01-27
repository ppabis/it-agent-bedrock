### Variables

variable "jira_base_url" {
  type        = string
  description = "Base URL for the Jira instance (e.g. https://your-jira-instance.atlassian.net)."
}

variable "jira_project_id" {
  type        = string
  description = "ID of the Jira project to create tickets in."
}

variable "db_access_issue_type_id" {
  type        = string
  description = "ID of the Jira issue type to create DB access tickets as."
}

variable "generic_issue_type_id" {
  type        = string
  description = "ID of the Jira issue type to create generic tickets as."
}

### Code

data "archive_file" "ticket_lambda" {
  type        = "zip"
  source_dir  = "lambdas/"
  output_path = "tickets_lambda.zip"
}

### Permissions

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.confluence.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ticket_lambda_role" {
  name               = "ticket_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "ticket_lambda_policy"
  role   = aws_iam_role.ticket_lambda_role.name
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.ticket_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

### Function

resource "aws_lambda_function" "ticket_lambda" {
  function_name    = "ticket_lambda"
  role             = aws_iam_role.ticket_lambda_role.arn
  handler          = "lambda_handler.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.ticket_lambda.output_path
  source_code_hash = data.archive_file.ticket_lambda.output_base64sha256
  depends_on       = [aws_iam_role_policy.lambda_policy]

  environment {
    variables = {
      JIRA_BASE_URL           = var.jira_base_url
      JIRA_PROJECT_ID         = var.jira_project_id
      DB_ACCESS_ISSUE_TYPE_ID = var.db_access_issue_type_id
      GENERIC_ISSUE_TYPE_ID   = var.generic_issue_type_id
      JIRA_SECRET_ARN         = aws_secretsmanager_secret.confluence.arn
    }
  }
}

### Resource policy

resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowBedrockInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ticket_lambda.arn
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.ticketagent.agent_arn
}