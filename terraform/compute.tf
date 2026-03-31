# =============================================================================
# Compute Instances
# =============================================================================

# --- Load Balancer (LB-01) ---
resource "yandex_compute_instance" "lb-01" {
  name        = "lb-01"
  description = "Nginx Load Balancer"
  hostname    = "lb-01"

  resources {
    cores         = var.instance_type["lb"].vcpu
    memory        = var.instance_type["lb"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "lb-01-root"
      type        = var.instance_type["lb"].disk_type
      size        = var.instance_type["lb"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lb.id
    v4_address         = "10.0.1.10"
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg_lb.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["lb"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.lb,
    yandex_vpc_security_group.sg_lb
  ]
}

# --- Application Server 1 (APP-01) ---
resource "yandex_compute_instance" "app-01" {
  name        = "app-01"
  description = "MediaWiki Application Server 1"
  hostname    = "app-01"

  resources {
    cores         = var.instance_type["app"].vcpu
    memory        = var.instance_type["app"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "app-01-root"
      type        = var.instance_type["app"].disk_type
      size        = var.instance_type["app"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app.id
    v4_address         = "10.0.2.10"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_app.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["app"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.app,
    yandex_vpc_security_group.sg_app
  ]
}

# --- Application Server 2 (APP-02) ---
resource "yandex_compute_instance" "app-02" {
  name        = "app-02"
  description = "MediaWiki Application Server 2"
  hostname    = "app-02"

  resources {
    cores         = var.instance_type["app"].vcpu
    memory        = var.instance_type["app"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "app-02-root"
      type        = var.instance_type["app"].disk_type
      size        = var.instance_type["app"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app.id
    v4_address         = "10.0.2.11"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_app.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["app"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.app,
    yandex_vpc_security_group.sg_app
  ]
}

# --- Database Server 1 (DB-01) - Primary ---
resource "yandex_compute_instance" "db-01" {
  name        = "db-01"
  description = "PostgreSQL Primary Server"
  hostname    = "db-01"

  resources {
    cores         = var.instance_type["db"].vcpu
    memory        = var.instance_type["db"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "db-01-root"
      type        = var.instance_type["db"].disk_type
      size        = var.instance_type["db"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.db.id
    v4_address         = "10.0.3.10"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_db.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["db"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.db,
    yandex_vpc_security_group.sg_db
  ]
}

# --- Database Server 2 (DB-02) - Replica ---
resource "yandex_compute_instance" "db-02" {
  name        = "db-02"
  description = "PostgreSQL Replica Server"
  hostname    = "db-02"

  resources {
    cores         = var.instance_type["db"].vcpu
    memory        = var.instance_type["db"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "db-02-root"
      type        = var.instance_type["db"].disk_type
      size        = var.instance_type["db"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.db.id
    v4_address         = "10.0.3.11"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_db.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["db"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.db,
    yandex_vpc_security_group.sg_db
  ]
}

# --- Zabbix Server (ZABBIX-01) ---
resource "yandex_compute_instance" "zabbix-01" {
  name        = "zabbix-01"
  description = "Zabbix Monitoring Server"
  hostname    = "zabbix-01"

  resources {
    cores         = var.instance_type["zabbix"].vcpu
    memory        = var.instance_type["zabbix"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "zabbix-01-root"
      type        = var.instance_type["zabbix"].disk_type
      size        = var.instance_type["zabbix"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.zabbix.id
    v4_address         = "10.0.4.10"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_zabbix.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["zabbix"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.zabbix,
    yandex_vpc_security_group.sg_zabbix
  ]
}

# --- Backup Server (BACKUP-01) ---
resource "yandex_compute_instance" "backup-01" {
  name        = "backup-01"
  description = "Backup Storage Server"
  hostname    = "backup-01"

  resources {
    cores         = var.instance_type["backup"].vcpu
    memory        = var.instance_type["backup"].memory
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id    = local.ubuntu_image
      name        = "backup-01-root"
      type        = var.instance_type["backup"].disk_type
      size        = var.instance_type["backup"].disk
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.backup.id
    v4_address         = "10.0.5.10"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg_backup.id]
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  scheduling_policy {
    preemptible = var.instance_type["backup"].preemptible
  }

  labels = local.common_tags

  depends_on = [
    yandex_vpc_subnet.backup,
    yandex_vpc_security_group.sg_backup
  ]
}
