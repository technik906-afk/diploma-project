# =============================================================================
# Security Groups
# =============================================================================

# --- Security Group для балансировщика (LB) ---
resource "yandex_vpc_security_group" "sg_lb" {
  name        = "sg-lb"
  description = "Security group для балансировщика нагрузки"
  network_id  = yandex_vpc_network.mediawiki.id

  labels = local.common_tags

  # HTTP из интернета
  ingress {
    protocol       = "TCP"
    description    = "HTTP from Internet"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS из интернета
  ingress {
    protocol       = "TCP"
    description    = "HTTPS from Internet"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH от админа
  ingress {
    protocol       = "TCP"
    description    = "SSH from Admin"
    port           = 22
    v4_cidr_blocks = ["${var.admin_ip}/32"]
  }

  # Исходящий весь
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group для приложений (APP) ---
resource "yandex_vpc_security_group" "sg_app" {
  name        = "sg-app"
  description = "Security group для серверов приложений"
  network_id  = yandex_vpc_network.mediawiki.id

  labels = local.common_tags

  # HTTP только от балансировщика
  ingress {
    protocol       = "TCP"
    description    = "HTTP from LB"
    port           = 80
    v4_cidr_blocks = [var.subnets["lb"].cidr]
  }

  # SSH от админа
  ingress {
    protocol       = "TCP"
    description    = "SSH from Admin"
    port           = 22
    v4_cidr_blocks = ["${var.admin_ip}/32"]
  }

  # Исходящий весь
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group для базы данных (DB) ---
resource "yandex_vpc_security_group" "sg_db" {
  name        = "sg-db"
  description = "Security group для серверов БД"
  network_id  = yandex_vpc_network.mediawiki.id

  labels = local.common_tags

  # PostgreSQL от приложений
  ingress {
    protocol       = "TCP"
    description    = "PostgreSQL from APP"
    port           = 5432
    v4_cidr_blocks = [var.subnets["app"].cidr]
  }

  # PostgreSQL от backup сервера
  ingress {
    protocol       = "TCP"
    description    = "PostgreSQL from BACKUP"
    port           = 5432
    v4_cidr_blocks = ["${var.subnets["backup"].cidr}"]
  }

  # SSH от админа
  ingress {
    protocol       = "TCP"
    description    = "SSH from Admin"
    port           = 22
    v4_cidr_blocks = ["${var.admin_ip}/32"]
  }

  # Исходящий весь
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group для Zabbix ---
resource "yandex_vpc_security_group" "sg_zabbix" {
  name        = "sg-zabbix"
  description = "Security group для сервера Zabbix"
  network_id  = yandex_vpc_network.mediawiki.id

  labels = local.common_tags

  # HTTP из интернета (для веб-интерфейса)
  ingress {
    protocol       = "TCP"
    description    = "HTTP from Internet"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Zabbix Agent от всех внутренних
  ingress {
    protocol       = "TCP"
    description    = "Zabbix Agent from internal"
    port           = 10050
    v4_cidr_blocks = ["10.0.0.0/8"]
  }

  # Zabbix Trapper от всех внутренних
  ingress {
    protocol       = "TCP"
    description    = "Zabbix Trapper from internal"
    port           = 10051
    v4_cidr_blocks = ["10.0.0.0/8"]
  }

  # SSH от админа
  ingress {
    protocol       = "TCP"
    description    = "SSH from Admin"
    port           = 22
    v4_cidr_blocks = ["${var.admin_ip}/32"]
  }

  # Исходящий весь
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group для backup сервера ---
resource "yandex_vpc_security_group" "sg_backup" {
  name        = "sg-backup"
  description = "Security group для сервера бэкапов"
  network_id  = yandex_vpc_network.mediawiki.id

  labels = local.common_tags

  # SSH от приложений и БД
  ingress {
    protocol       = "TCP"
    description    = "SSH from APP and DB"
    port           = 22
    v4_cidr_blocks = [var.subnets["app"].cidr, var.subnets["db"].cidr]
  }

  # Исходящий весь
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
