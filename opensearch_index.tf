locals {
  index_name            = "ticketagent_index"
  vector_dimension      = 256
  vector_text_field     = "chunk"
  vector_metadata_field = "metadata"
  vector_field          = "vector"
  schema = jsonencode({
    settings = {
      index = {
        knn = true
        "knn.algo_param.ef_search" : 512
      }
    },
    mappings = {
      properties = {
        "${local.vector_field}" = {
          type      = "knn_vector"
          dimension = local.vector_dimension
          method = {
            name       = "hnsw"
            engine     = "faiss"
            parameters = {}
            space_type = "l2"
          }
        }
        "${local.vector_text_field}" = {
          type  = "text"
          index = "true"
        }
        "${local.vector_metadata_field}" = {
          type  = "text"
          index = "false"
        }
      }
    }
  })
}

resource "null_resource" "index" {
  provisioner "local-exec" {
    command = "aws opensearchserverless create-index --region ${data.aws_region.current.name} --id ${aws_opensearchserverless_collection.knowledge_base.id} --index-name ${local.index_name} --index-schema '${local.schema}'"
  }
  depends_on = [aws_opensearchserverless_collection.knowledge_base, aws_opensearchserverless_access_policy.data_policy, aws_opensearchserverless_security_policy.network]
  lifecycle {
    replace_triggered_by = [aws_opensearchserverless_collection.knowledge_base]
  }
}