output "admin_password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.main.admin_password
}