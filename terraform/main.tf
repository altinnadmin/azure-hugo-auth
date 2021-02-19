terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.47.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "hugo"
    storage_account_name = "hugotf"
    container_name       = "terraform-state"
    key                  = "hugo.tfstate"
  }
}

provider "azurerm" {
  # Configuration options
  features {}
}

resource "azurerm_storage_account" "main" {
  name                     = var.storageaccountname
  resource_group_name      = var.resourcegroup
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "content" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
data "azurerm_storage_account_blob_container_sas" "content" {
  connection_string = azurerm_storage_account.main.primary_connection_string
  container_name    = azurerm_storage_container.content.name
  https_only        = true

  start  = "2021-02-18"
  expiry = "2021-02-20"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}
resource "azurerm_app_service_plan" "proxy" {
  name                = "${var.proxyname}-service-plan"
  location            = var.location
  resource_group_name = var.resourcegroup
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "proxy" {
  name                       = var.proxyname
  location                   = var.location
  resource_group_name        = var.resourcegroup
  app_service_plan_id        = azurerm_app_service_plan.proxy.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  os_type                    = "linux"
  https_only                 = true
  app_settings = {
    "BLOB_SERVICE_ENDPOINT" = azurerm_storage_account.main.primary_blob_endpoint
    "BLOB_CONTAINER" = azurerm_storage_container.content.name
    "BLOB_ACCESS_STRING" = "?${data.azurerm_storage_account_blob_container_sas.content.sas}"
  }
}
