# =============================================================================
# Local Values
# =============================================================================

locals {
  # Общие метки для всех ресурсов
  common_tags = {
    project     = var.project_name
    environment = "development"
    managed_by  = "terraform"
    author      = "technik906-afk"
  }

  # Образ Ubuntu 22.04
  ubuntu_image = data.yandex_compute_image.ubuntu.id

  # SSH ключи (формат: username:ssh-key)
  ssh_keys = [for key in var.ssh_public_keys : "ubuntu:${key}"]
}

# =============================================================================
# Data Sources
# =============================================================================

data "yandex_compute_image" "ubuntu" {
  family    = var.image_family
  folder_id = var.image_folder_id
}
