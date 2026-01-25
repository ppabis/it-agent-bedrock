output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.confluence.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.confluence.id
}