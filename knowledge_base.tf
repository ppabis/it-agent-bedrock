variable "confluence_instance_url" {
  type        = string
  description = "Base URL for the Confluence Cloud site (e.g. https://org.atlassian.net)."
}

locals {
  embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
}

data "aws_iam_policy_document" "bedrock_kb_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bedrock_kb_role" {
  name               = "ticketagent-bedrock-kb-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_kb_assume_role.json
}

data "aws_iam_policy_document" "bedrock_kb_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.confluence.arn]
  }

  statement {
    effect = "Allow"
    actions = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test = "StringLike"
      variable = "kms:ViaService"
      values = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:StartIngestionJob",
      "bedrock:CreateDataSource",
      "bedrock:GetDataSource",
      "bedrock:DescribeKnowledgeBase",
      "bedrock:Retrieve"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    resources = [aws_opensearchserverless_collection.knowledge_base.arn]
  }
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name   = "ticketagent-bedrock-kb-policy"
  role   = aws_iam_role.bedrock_kb_role.id
  policy = data.aws_iam_policy_document.bedrock_kb_policy.json
}


resource "aws_bedrockagent_knowledge_base" "confluence" {
  depends_on  = [null_resource.index]
  name        = "ticketagent-confluence-kb"
  role_arn    = aws_iam_role.bedrock_kb_role.arn
  description = "Confluence knowledge base backed by OpenSearch Serverless."

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = local.vector_dimension
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.knowledge_base.arn
      vector_index_name = local.index_name
      field_mapping {
        vector_field   = local.vector_field
        text_field     = local.vector_text_field
        metadata_field = local.vector_metadata_field
      }
    }
  }

}

resource "aws_bedrockagent_data_source" "confluence" {
  name              = "ticketagent-confluence-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.confluence.id

  data_source_configuration {
    type = "CONFLUENCE"
    confluence_configuration {
      source_configuration {
        host_url               = var.confluence_instance_url
        host_type              = "SAAS"
        auth_type              = "BASIC"
        credentials_secret_arn = aws_secretsmanager_secret.confluence.arn
      }
    }
  }
}