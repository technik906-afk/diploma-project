# =============================================================================
# Outputs
# =============================================================================

output "lb_public_ip" {
  description = "Публичный IP адрес балансировщика (LB-01)"
  value       = yandex_compute_instance.lb-01.network_interface[0].nat_ip_address
}

output "lb_private_ip" {
  description = "Частный IP адрес балансировщика (LB-01)"
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

output "zabbix_private_ip" {
  description = "Частный IP адрес сервера Zabbix"
  value       = yandex_compute_instance.zabbix-01.network_interface[0].ip_address
}

output "backup_private_ip" {
  description = "Частный IP адрес сервера бэкапов"
  value       = yandex_compute_instance.backup-01.network_interface[0].ip_address
}

output "ssh_jump_host" {
  description = "SSH Jump Host (публичный IP LB-01)"
  value       = yandex_compute_instance.lb-01.network_interface[0].nat_ip_address
}

output "ssh_commands" {
  description = "Команды для подключения к серверам через SSH jump"
  value = {
    lb     = "ssh -i ~/.ssh/yandex_cloud ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address}"
    app-01 = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.2.10"
    app-02 = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.2.11"
    db-01  = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.3.10"
    db-02  = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.3.11"
    zabbix = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.4.10"
    backup = "ssh -i ~/.ssh/yandex_cloud -J ubuntu@${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} ubuntu@10.0.5.10"
  }
}

output "ansible_inventory_hint" {
  description = "Подсказка для обновления Ansible inventory"
  value       = "Обновите ~/.ssh/config с HostName = ${yandex_compute_instance.lb-01.network_interface[0].nat_ip_address} для yc-lb"
}
