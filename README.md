Ticket processing agent
=========

This is a demo agent that will process and create some predefined JIRA tickets
and use Confluence knowledge base to provide information as well as use it to
validate the tickets to create.

Configure your Confluence credentials in `terraform.tfvars`. Specify
`confluence_username`. For the password (API key) I suggest reading it only into
env for the time being when you apply the infra. Do it like this:

```bash
read -s TF_VAR_confluence_password
# Paste the key and enter
export TF_VAR_confluence_password
tofu apply
```
