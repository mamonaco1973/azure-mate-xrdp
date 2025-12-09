# ==============================================================================
# Friendly password generator (all accounts)
# ------------------------------------------------------------------------------
# Builds passwords for every AD-related account using <word>-<number>.
# All passwords stored in local.passwords for consistent referencing.
# ==============================================================================

# ------------------------------------------------------------------------------
# Word list used for memorable passwords
# ------------------------------------------------------------------------------
locals {
  memorable_words = [
    "bright", "simple", "orange", "window", "little", "people",
    "friend", "yellow", "animal", "family", "circle", "moment",
    "summer", "button", "planet", "rocket", "silver", "forest",
    "stream", "butter", "castle", "wonder", "gentle", "driver",
    "coffee"
  ]
}

# ------------------------------------------------------------------------------
# All AD accounts (admin, sysadmin, sample users)
# ------------------------------------------------------------------------------
locals {
  ad_accounts = {
    admin    = "Admin"
    sysadmin = "Sysadmin"
    jsmith   = "John Smith"
    edavis   = "Emily Davis"
    rpatel   = "Raj Patel"
    akumar   = "Amit Kumar"
  }
}

# ------------------------------------------------------------------------------
# Pick one random word per account
# ------------------------------------------------------------------------------
resource "random_shuffle" "word" {
  for_each     = local.ad_accounts
  input        = local.memorable_words
  result_count = 1
}

# ------------------------------------------------------------------------------
# Pick one random 6-digit number per account
# ------------------------------------------------------------------------------
resource "random_integer" "num" {
  for_each = local.ad_accounts
  min      = 100000
  max      = 999999
}

# ------------------------------------------------------------------------------
# Build all passwords as <word>-<number> for every account
# ------------------------------------------------------------------------------
locals {
  passwords = {
    for u, _ in local.ad_accounts :
    u => "${random_shuffle.word[u].result[0]}-${random_integer.num[u].result}"
  }
}

# ==============================================================================
# Key Vault secrets for all accounts
# ------------------------------------------------------------------------------
# Username rules:
#   admin    → Admin@<dns_zone>
#   sysadmin → sysadmin
#   users    → <username>@<dns_zone>
# ==============================================================================
resource "azurerm_key_vault_secret" "account_secret" {
  for_each = local.ad_accounts

  name         = "${each.key}-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"

  value = jsonencode({
    username = (
      each.key == "admin"    ? "Admin@${var.dns_zone}" :
      each.key == "sysadmin" ? "sysadmin" :
                               "${each.key}@${var.dns_zone}"
    )
    password = local.passwords[each.key]
  })

  depends_on = [azurerm_role_assignment.kv_role_assignment]
}
