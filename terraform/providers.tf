terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.121"
    }
  }
}

provider "yandex" {
  # Сервисный аккаунт для Terraform
  # Создайте файл credentials.tfvars с содержимым:
  # service_account_key_file = file("~/.authorized_key.json")
  # И добавьте его в .gitignore!
  
  service_account_key_file = var.service_account_key_file
  
  # Облако и папка
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  
  # Зона по умолчанию
  zone = var.region
}
