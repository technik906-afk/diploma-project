# =============================================================================
# VPC Network
# =============================================================================

resource "yandex_vpc_network" "mediawiki" {
  name = var.vpc_name

  labels = local.common_tags
}

# =============================================================================
# Subnets
# =============================================================================

resource "yandex_vpc_subnet" "lb" {
  name           = var.subnets["lb"].name
  zone           = var.subnets["lb"].zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnets["lb"].cidr]

  labels = local.common_tags
}

resource "yandex_vpc_subnet" "app" {
  name           = var.subnets["app"].name
  zone           = var.subnets["app"].zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnets["app"].cidr]

  labels = local.common_tags
}

resource "yandex_vpc_subnet" "db" {
  name           = var.subnets["db"].name
  zone           = var.subnets["db"].zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnets["db"].cidr]

  labels = local.common_tags
}

resource "yandex_vpc_subnet" "zabbix" {
  name           = var.subnets["zabbix"].name
  zone           = var.subnets["zabbix"].zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnets["zabbix"].cidr]

  labels = local.common_tags
}

resource "yandex_vpc_subnet" "backup" {
  name           = var.subnets["backup"].name
  zone           = var.subnets["backup"].zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnets["backup"].cidr]

  labels = local.common_tags
}
