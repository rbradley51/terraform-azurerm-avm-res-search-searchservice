# Shared Private Link Service example

This example deploys an Azure AI Search service with Shared Private Link Services to an Azure Storage Account.

## Features demonstrated

- Azure AI Search service with private endpoint
- Storage Account with Blob storage and private endpoint
- Shared Private Link Service from Search Service to Storage Account blob endpoint
- Private DNS zones for Search Service and Blob endpoints
- All resources deployed in the same virtual network

This example shows how to use Shared Private Link Services to allow the Search Service to securely access storage accounts over the Azure backbone network.
