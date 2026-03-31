# =============================================================================
# Local Values
# =============================================================================

locals {
  # Общие метки для всех ресурсов
  common_tags = {
    Project     = var.project_name
    Environment = "development"
    ManagedBy   = "terraform"
    Author      = "technik906-afk"
  }

  # Образ Ubuntu 22.04
  ubuntu_image = data.yandex_compute_image.ubuntu.self_link

  # SSH ключи
  ssh_keys = var.ssh_public_keys
}

# =============================================================================
# Data Sources
# =============================================================================

data "yandex_compute_image" "ubuntu" {
  family    = var.image_family
  folder_id = var.image_folder_id
}

# =============================================================================
# Outputs
# =============================================================================

output "lb_public_ip" {
  description = "Публичный IP адрес балансировщика"
  value       = yandex_compute_instance.lb-01.network_interface[0].nat_ip_address
}

output "lb_private_ip" {
  description = "Частный IP адрес балансировщика"
  value       = yandex_compute_instance.lb-01.network_interface[0].ip_address
}

output "app_instances" {
  description = "Частные IP адреса серверов приложений"
  value = {
    app-01 = yandex_compute_instance.app-01.network_interface[0].ip_address
    app-02 = yandex_compute_instance.app-02.network_interface[0].ip_address
  }
}

output "db_instances" {
  description = "Частные IP адреса серверов БД"
  value = {
    db-01 = yandex_compute_instance.db-01.network_interface[0].ip_address
    db-02 = yandex_compute_instance.db-02.network_interface[0].ip_address
  }
}

output "zabbix_ip" {
  description = "Частный IP адрес сервера Zabbix"
  value       = yandex_compute_instance.zabbix-01.network_interface[0].ip_address
}

output "backup_ip" {
  description = "Частный IP адрес сервера бэкапов"
  value       = yandex_compute_instance.backup-01.network_interface[0].ip_address
}

output "ssh_jump_command" {
  description = "Команда для SSH через jump-host"
  value       = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@<private-ip>"
}
