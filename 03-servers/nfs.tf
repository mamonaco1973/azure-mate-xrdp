# ==============================================================================
# Azure Files (NFS 4.1) with Private Endpoint
# ------------------------------------------------------------------------------
# Provisions a Premium FileStorage account with an NFS-enabled file share and
# exposes it securely over a private endpoint. A private DNS zone provides name
# resolution, and Linux VMs in the VNet can mount the share privately.
#
# Key points:
#   - Premium FileStorage required for NFS 4.1.
#   - NFS share minimum quota is 100 GiB.
#   - Public access disabled; traffic stays in the VNet.
#   - Private DNS zone resolves file endpoints to private IPs.
# ==============================================================================
resource "azurerm_storage_account" "nfs_storage_account" {

  # ----------------------------------------------------------------------------
  # Storage account configuration
  # ----------------------------------------------------------------------------
  # - Name must be unique, lowercase, and 3–24 chars long.
  # - Premium FileStorage SKU required for NFS 4.1.
  # - LRS replication used for labs/demos.
  # - Public access disabled; private endpoint only.
  name                         = "nfs${random_string.vm_suffix.result}"
  resource_group_name          = data.azurerm_resource_group.mate.name
  location                     = data.azurerm_resource_group.mate.location
  account_kind                 = "FileStorage"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  public_network_access_enabled = false
}

# ==============================================================================
# NFS file share
# ------------------------------------------------------------------------------
# Creates an NFS-enabled share inside the Premium FileStorage account.
#
# Key points:
#   - NFS protocol explicitly enabled.
#   - Minimum quota for Premium NFS is 100 GiB.
# ==============================================================================
resource "azurerm_storage_share" "nfs" {
  name               = "nfs"
  storage_account_id = azurerm_storage_account.nfs_storage_account.id
  enabled_protocol   = "NFS"
  quota              = 100
}

# ==============================================================================
# Private DNS zone for Azure Files
# ------------------------------------------------------------------------------
# Provides DNS resolution for private endpoints:
#   privatelink.file.core.windows.net
# VMs in the VNet resolve the file service to the private endpoint’s IP.
# ==============================================================================
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = data.azurerm_resource_group.mate.name
}

# ------------------------------------------------------------------------------
# VNet link for private DNS zone
# ------------------------------------------------------------------------------
# Links the private DNS zone to the AD VNet so VMs resolve Azure Files privately.
resource "azurerm_private_dns_zone_virtual_network_link" "file_link" {
  name                  = "vnet-link"
  resource_group_name   = data.azurerm_resource_group.mate.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = data.azurerm_virtual_network.ad_vnet.id
}

# ==============================================================================
# Private endpoint (file subresource)
# ------------------------------------------------------------------------------
# Creates a private endpoint for the storage account "file" service.
#
# Key points:
#   - Ensures private connectivity to the file share.
#   - DNS zone group registers private DNS records automatically.
# ==============================================================================
resource "azurerm_private_endpoint" "pe_file" {
  name                = "pe-st-file"
  location            = data.azurerm_resource_group.mate.location
  resource_group_name = data.azurerm_resource_group.mate.name
  subnet_id           = data.azurerm_subnet.vm_subnet.id

  # ----------------------------------------------------------------------------
  # Private service connection
  # ----------------------------------------------------------------------------
  # Connects the private endpoint to the "file" subresource of the storage acct.
  private_service_connection {
    name                           = "sc-st-file"
    private_connection_resource_id = azurerm_storage_account.nfs_storage_account.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  # ----------------------------------------------------------------------------
  # Private DNS zone group
  # ----------------------------------------------------------------------------
  # Attaches the private endpoint to the private DNS zone for automatic records.
  private_dns_zone_group {
    name                 = "pdzg-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }
}

# ==============================================================================
# (Optional) Linux mount command output
# ------------------------------------------------------------------------------
# Provides example mount steps for Linux clients. Commented out to avoid extra
# output unless needed.
# ==============================================================================
# output "nfs_mount_command" {
#   value = <<EOT
# sudo apt-get -y install nfs-common
# sudo mkdir -p /mnt/azurefiles
# sudo mount -t nfs -o vers=4.1,sec=sys \
#   ${azurerm_storage_account.nfs_storage_account.name}.file.core.windows.net:/${azurerm_storage_share.nfs.name} /mnt/azurefiles
# EOT
# }
