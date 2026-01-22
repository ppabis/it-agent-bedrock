locals {
  collection_name = "ticketagent-collection"
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "ticketagent-network"
  type = "network"
  policy = jsonencode([
    {
      # SourceServices  = ["bedrock.amazonaws.com"],
      Rules           = [{ ResourceType = "collection", Resource = ["collection/${aws_opensearchserverless_collection.knowledge_base.name}"] }],
      AllowFromPublic = true
    }
  ])
}


resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "ticketagent-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${local.collection_name}"]
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_access_policy" "data_policy" {
  name = "ticketagent-data-policy"
  type = "data"
  policy = jsonencode([
    {
      Description = "Full access"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.knowledge_base.name}"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${aws_opensearchserverless_collection.knowledge_base.name}/*"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "model"
          Resource     = ["model/${aws_opensearchserverless_collection.knowledge_base.name}/*"]
          Permission   = ["aoss:*"]
        }
      ]
      Principal = [
        data.aws_caller_identity.current.arn,
        aws_iam_role.bedrock_kb_role.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "knowledge_base" {
  name             = "ticketagent-collection"
  description      = "OpenSearch Serverless collection powering the Bedrock KB"
  depends_on       = [aws_opensearchserverless_security_policy.encryption]
  type             = "VECTORSEARCH"
  standby_replicas = "DISABLED"
}