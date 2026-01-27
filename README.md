Ticket processing agent
=========

This is a demo agent that will process and create some predefined JIRA tickets
and use Confluence knowledge base to provide information as well as use it to
validate the tickets to create.

Read more in my blog posts:

- [on pabis.eu](https://pabis.eu/blog/2026-01-25-IT-Support-Agent-AWS-Bedrock-Confluence.html)
- [on dev.to](https://dev.to/aws-builders/it-support-agent-on-aws-bedrock-connecting-confluence-l6i)

Building the infrastructure
----------

Configure your Confluence credentials in `terraform.tfvars`. Specify
`confluence_username`, `confluence_instance_url`. For the password (API key) I
suggest reading it only into env for the time being when you apply the infra. Do
it like this:

```bash
read -s TF_VAR_confluence_password
# Paste the key and enter
export TF_VAR_confluence_password
tofu apply
```

It could happen that during index creation the process fails (due to delay in
applying OpenSearch policies). Simply try to plan and apply again.

Lambda requirements
--------

Install Lambda requirements using Docker with Amazon Linux 2023 for full
compatibility. Run the following command before deploying the Lambda.

```bash
docker run --rm -it \
 -v $(pwd)/lambdas:/lambdas amazonlinux:2023 \
 sh -c 'yum install python3-pip -y && pip install -t /lambdas/ requests'
```

Get JIRA field IDs, etc
-----------------

In order to make the Lambda functional and post JIRA tickets, you need to adapt
it to your liking and use cases. For that, useful functions were added to
`tools/get_fields.sh`. Edit the file and provide your own configuration.
