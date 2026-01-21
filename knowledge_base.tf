resource "aws_s3vectors_vector_bucket" "knowledge_base" {
  vector_bucket_name = "ticketagent-bucket"
}

resource "aws_s3vectors_index" "knowledge_base" {
  vector_bucket_name = aws_s3vectors_vector_bucket.knowledge_base.vector_bucket_name
  index_name         = "ticketagent-index"
  data_type          = "float32"
  dimension          = 256
  distance_metric    = "cosine"

  metadata_configuration {
    non_filterable_metadata_keys = ["AMAZON_BEDROCK_TEXT"]
  }
}