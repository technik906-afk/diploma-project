# =============================================================================
# Yandex Cloud Variables
# =============================================================================

variable "service_account_key_file" {
  description = "Путь к файлу ключа сервисного аккаунта"
  type        = string
  sensitive   = true
}

variable "cloud_id" {
  description = "ID облака Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "ID папки Yandex Cloud"
  type        = string
}

variable "region" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

# =============================================================================
# Project Variables
# =============================================================================

variable "project_name" {
  description = "Имя проекта"
  type        = string
  default     = "mediawiki"
}

variable "admin_ip" {
  description = "IP адрес администратора для доступа по SSH"
  type        = string
}

variable "ssh_public_keys" {
  description = "Список SSH публичных ключей для доступа к ВМ"
  type        = list(string)
  default     = []
}

# =============================================================================
# Instance Types Configuration
# =============================================================================

variable "instance_type" {
  description = "Конфигурация типов инстансов"
  type = map(object({
    vcpu        = number
    memory      = number
    disk        = number
    disk_type   = string
    preemptible = bool
  }))
  default = {
    lb     = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    app    = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    db     = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    zabbix = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    backup = { vcpu = 2, memory = 2, disk = 30, disk_type = "network-hdd", preemptible = true }
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_name" {
  description = "Имя VPC сети"
  type        = string
  default     = "mediawiki-vpc"
}

variable "subnets" {
  description = "Конфигурация подсетей"
  type = map(object({
    cidr     = string
    zone     = string
    name     = string
  }))
  default = {
    lb     = { cidr = "10.0.1.0/24", zone = "ru-central1-a", name = "lb-subnet" }
    app    = { cidr = "10.0.2.0/24", zone = "ru-central1-a", name = "app-subnet" }
    db     = { cidr = "10.0.3.0/24", zone = "ru-central1-a", name = "db-subnet" }
    zabbix = { cidr = "10.0.4.0/24", zone = "ru-central1-a", name = "zabbix-subnet" }
    backup = { cidr = "10.0.5.0/24", zone = "ru-central1-a", name = "backup-subnet" }
  }
}

# =============================================================================
# VM Configuration
# =============================================================================

variable "image_family" {
  description = "Семейство образов ОС"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_folder_id" {
  description = "ID папки с образами (standard-images)"
  type        = string
  default     = "standard-images"
}
