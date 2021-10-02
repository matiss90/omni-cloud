# How to maintain backups in Azure?
This is a solution prepared for automation of the Azure backup solution. More details you can be found in the blog post: https://omni-cloud.eu/jak-zapanowac-nad-backupami-w-azure/

## Usage
The codebase is prepared in Terraform, and you need to run it with some parameters defined in `inputs.tf` file.

Example command:
```
tf plan \
  -var subscription_id="" \
  -var client_id="" \
  -var client_secret="" \
  -var tenant_id="" \
  -out=my.tfplan
```
