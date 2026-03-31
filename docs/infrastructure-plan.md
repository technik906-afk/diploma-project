# Полный план реализации дипломного проекта: MediaWiki в Yandex Cloud

---

## 📋 Содержание

1. [Общая информация](#общая-информация)
2. [Схема архитектуры](#схема-архитектуры)
3. [Конфигурация серверов](#конфигурация-серверов)
4. [Сетевая схема](#сетевая-схема)
5. [Security Groups](#security-groups)
6. [Доступ к серверам](#доступ-к-серверам)
7. [Terraform конфигурация](#terraform-конфигурация)
8. [Ansible инвентори](#ansible-инвентори)
9. [План работ по этапам](#план-работ-по-этапам)
10. [Стоимость](#стоимость)

---

## Общая информация

| Параметр | Значение |
|----------|----------|
| **Облачный провайдер** | Yandex Cloud |
| **ОС** | Ubuntu 22.04 LTS |
| **Регион** | ru-central1-a |
| **VPC** | mediawiki-vpc |
| **Тип ВМ** | Прерываемые (preemptible) |
| **Тип диска** | Сетевой HDD (network-hdd) |
| **Количество серверов** | 7 |

---

## Схема архитектуры

```
┌──────────────────────────────────────────────────────────────────┐
│                         Yandex Cloud VPC                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Security Group                          │ │
│  │                                                            │ │
│  │  ┌─────────────┐                                           │ │
│  │  │   LB-01     │  nginx load balancer                      │ │
│  │  │  (2 vCPU,   │  port: 80, 443                            │ │
│  │  │   2GB RAM)  │  Public IP: ✓                             │ │
│  │  └──────┬──────┘                                           │ │
│  │         │                                                  │ │
│  │    ┌────┴────┐                                             │ │
│  │    ▼         ▼                                             │ │
│  │  ┌───────────┐   ┌───────────┐                             │ │
│  │  │  APP-01   │   │  APP-02   │                             │ │
│  │  │ MediaWiki │   │ MediaWiki │                            │ │
│  │  │ (2 vCPU,  │   │ (2 vCPU,  │                             │ │
│  │  │  2GB RAM) │   │  2GB RAM) │                             │ │
│  │  └─────┬─────┘   └─────┬─────┘                             │ │
│  │        │               │                                   │ │
│  │        └───────┬───────┘                                   │ │
│  │                ▼                                           │ │
│  │        ┌───────┴───────┐                                   │ │
│  │        ▼               ▼                                   │ │
│  │  ┌───────────┐   ┌───────────┐                             │ │
│  │  │  DB-01    │   │  DB-02    │                             │ │
│  │  │ PostgreSQL│   │ PostgreSQL│                            │ │
│  │  │  Master   │◄──┤  Replica  │                             │ │
│  │  │ (2 vCPU,  │   │ (2 vCPU,  │                             │ │
│  │  │  2GB RAM) │   │  2GB RAM) │                             │ │
│  │  └─────┬─────┘   └─────┬─────┘                             │ │
│  │        │               │                                   │ │
│  │        ▼               ▼                                   │ │
│  │  ┌───────────────────────────┐                             │ │
│  │  │     ZABBIX-01             │                             │ │
│  │  │   Zabbix Server + Agent   │                             │ │
│  │  │      (2 vCPU, 2GB RAM)    │                             │ │
│  │  └─────────────┬─────────────┘                             │ │
│  │                │                                           │ │
│  │                ▼                                           │ │
│  │  ┌───────────────────────────┐                             │ │
│  │  │    BACKUP-01              │                             │ │
│  │  │   Backup Storage Server   │                             │ │
│  │  │      (2 vCPU, 2GB RAM)    │                             │ │
│  │  │      + 30GB Disk          │                             │ │
│  │  └───────────────────────────┘                             │ │
│  │                                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘

Потоки трафика:
  ──────────────
  Пользователи → LB-01 → APP-01/APP-02 → DB-01/DB-02
  Все серверы → ZABBIX-01 (мониторинг)
  DB-01/APP-01 → BACKUP-01 (бэкапы)
  Вы → LB-01 (Public IP) → остальные серверы (SSH jump)
```

---

## Конфигурация серверов

| # | Сервер | Роль | vCPU | RAM | Disk | Прерываемая | Public IP | Частный IP |
|---|--------|------|------|-----|------|-------------|-----------|------------|
| 1 | **LB-01** | Nginx Load Balancer | 2 | 2 GB | 20 GB HDD | ✅ Да | ✅ Да | 10.0.1.10 |
| 2 | **APP-01** | MediaWiki App | 2 | 2 GB | 20 GB HDD | ✅ Да | ❌ Нет | 10.0.2.10 |
| 3 | **APP-02** | MediaWiki App | 2 | 2 GB | 20 GB HDD | ✅ Да | ❌ Нет | 10.0.2.11 |
| 4 | **DB-01** | PostgreSQL Primary | 2 | 2 GB | 20 GB HDD | ✅ Да | ❌ Нет | 10.0.3.10 |
| 5 | **DB-02** | PostgreSQL Replica | 2 | 2 GB | 20 GB HDD | ✅ Да | ❌ Нет | 10.0.3.11 |
| 6 | **ZABBIX-01** | Zabbix Server | 2 | 2 GB | 20 GB HDD | ✅ Да | ❌ Нет | 10.0.4.10 |
| 7 | **BACKUP-01** | Backup Storage | 2 | 2 GB | 30 GB HDD | ✅ Да | ❌ Нет | 10.0.5.10 |

---

## Сетевая схема

```
VPC: mediawiki-vpc (10.0.0.0/16)

┌─────────────────────────────────────────────────────────────────────┐
│ Подсеть         | CIDR        | Назначение                          │
├─────────────────────────────────────────────────────────────────────┤
│ lb-subnet       | 10.0.1.0/24 | Балансировщик (LB-01)               │
│ app-subnet      | 10.0.2.0/24 | Приложение MediaWiki (APP-01,02)    │
│ db-subnet       | 10.0.3.0/24 | База данных PostgreSQL (DB-01,02)   │
│ zabbix-subnet   | 10.0.4.0/24 | Мониторинг Zabbix (ZABBIX-01)       │
│ backup-subnet   | 10.0.5.0/24 | Сервер бэкапов (BACKUP-01)          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Security Groups

### sg-lb (Балансировщик)
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP | Inbound | 80 | 0.0.0.0/0 |
| HTTPS | Inbound | 443 | 0.0.0.0/0 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-app (Приложение)
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP from LB | Inbound | 80 | 10.0.1.10 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-db (База данных)
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| PostgreSQL from APP | Inbound | 5432 | 10.0.2.0/24 |
| PostgreSQL from BACKUP | Inbound | 5432 | 10.0.5.10 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-zabbix (Мониторинг)
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP | Inbound | 80 | 0.0.0.0/0 |
| Zabbix Agent | Inbound | 10050 | 10.0.0.0/8 |
| Zabbix Trapper | Inbound | 10051 | 10.0.0.0/8 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-backup (Бэкапы)
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| SSH from DB, APP | Inbound | 22 | 10.0.2.0/24, 10.0.3.0/24 |
| All Outbound | Outbound | All | 0.0.0.0/0 |

---

## Доступ к серверам

### Вариант 1: SSH через jump-host (рекомендуется)

Только LB-01 имеет публичный IP. К остальным ВМ подключаемся через него:

```bash
# К LB-01 напрямую
ssh -i ~/.ssh/yandex_cloud ubuntu@<lb-public-ip>

# К APP-01 через LB-01 (SSH jump)
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.2.10

# К APP-02 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.2.11

# К DB-01 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.3.10

# К DB-02 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.3.11

# К ZABBIX-01 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.4.10

# К BACKUP-01 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.5.10
```

### Вариант 2: Прямой доступ (все публичные IP)

| Сервер | Public IP |
|--------|-----------|
| LB-01 | Да |
| APP-01 | Да |
| APP-02 | Да |
| DB-01 | Да |
| DB-02 | Да |
| ZABBIX-01 | Да |
| BACKUP-01 | Да |

**Дополнительная стоимость:** ~0.03 руб/час за каждый IP ≈ **22 руб/мес за 6 дополнительных IP**

---

## Terraform конфигурация

### variables.tf

```hcl
variable "region" {
  default = "ru-central1-a"
}

variable "vpc_name" {
  default = "mediawiki-vpc"
}

variable "instance_type" {
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

variable "admin_ssh_keys" {
  description = "SSH публичные ключи администраторов"
  type        = list(string)
}

variable "admin_ip" {
  description = "IP адрес администратора для доступа по SSH"
  type        = string
}
```

---

## Ansible инвентори

### ~/.ssh/config (для SSH jump)

```ssh
Host yc-lb
    HostName <lb-public-ip>
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud

Host yc-app-01
    HostName 10.0.2.10
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb

Host yc-app-02
    HostName 10.0.2.11
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb

Host yc-db-01
    HostName 10.0.3.10
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb

Host yc-db-02
    HostName 10.0.3.11
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb

Host yc-zabbix
    HostName 10.0.4.10
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb

Host yc-backup
    HostName 10.0.5.10
    User ubuntu
    IdentityFile ~/.ssh/yandex_cloud
    ProxyJump yc-lb
```

### ansible/inventory/hosts.ini

```ini
[lb]
lb-01 ansible_host=yc-lb

[app]
app-01 ansible_host=yc-app-01
app-02 ansible_host=yc-app-02

[db]
db-01 ansible_host=yc-db-01 role=primary
db-02 ansible_host=yc-db-02 role=replica

[zabbix]
zabbix-01 ansible_host=yc-zabbix

[backup]
backup-01 ansible_host=yc-backup

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/yandex_cloud
ansible_python_interpreter=/usr/bin/python3
```

---

## План работ по этапам

### Этап 0. Подготовка (Terraform + Yandex Cloud)

| № | Задача | Артефакт |
|---|--------|----------|
| 0.1 | Создать VPC и подсети | Terraform |
| 0.2 | Настроить Security Groups | Terraform |
| 0.3 | Создать 7 VM с нужными параметрами | Terraform |
| 0.4 | Развернуть инфраструктуру | `terraform apply` |

### Этап 1. Проектирование инфраструктуры

| № | Задача | Артефакт |
|---|--------|----------|
| 1.1 | Оформить требования по шаблону | `docs/requirements.md` |
| 1.2 | Нарисовать схему в Diagrams.net | `docs/diagrams/architecture.png` |
| 1.3 | Описать план восстановления | `docs/recovery-plan.md` |

### Этап 2. Развёртывание (Ansible)

| № | Задача | Артефакт |
|---|--------|----------|
| 2.1 | Установить Nginx на LB-01 | `ansible/playbooks/nginx-lb.yml` |
| 2.2 | Установить MediaWiki на APP-01, APP-02 | `ansible/playbooks/mediawiki.yml` |
| 2.3 | Установить PostgreSQL на DB-01, DB-02 | `ansible/playbooks/postgresql.yml` |
| 2.4 | Настроить репликацию БД | `ansible/playbooks/pg-replication.yml` |
| 2.5 | Установить Zabbix на ZABBIX-01 | `ansible/playbooks/zabbix.yml` |
| 2.6 | Настроить бэкапы на BACKUP-01 | `ansible/playbooks/backup.yml` |

### Этап 3. Мониторинг (Zabbix)

| № | Задача | Артефакт |
|---|--------|----------|
| 3.1 | Настроить мониторинг HTTP (код, время ответа) | Zabbix templates |
| 3.2 | Добавить все хосты в Zabbix | Zabbix config |

### Этап 4. Отработка плана восстановления

| № | Задача | Артефакт |
|---|--------|----------|
| 4.1 | Выключить APP-сервер → проверить работу | Скриншоты/видео |
| 4.2 | Выключить DB-master → проверить переключение | Скриншоты/видео |
| 4.3 | Восстановить директорию из бэкапа | Лог |
| 4.4 | Восстановить БД из бэкапа | Лог |
| 4.5 | Записать презентацию | Видеофайл |

---

## Стоимость

> **Примечание:** Прерываемые ВМ дешевле до 70%, но могут быть остановлены облаком. Сетевые HDD дешевле SSD, но имеют меньшую производительность.

| Сервер | vCPU | RAM | Disk | Прерываемая | Цена/час (руб) | Цена/мес (руб) |
|--------|------|-----|------|-------------|----------------|----------------|
| LB-01 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| APP-01 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| APP-02 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| DB-01 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| DB-02 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| ZABBIX-01 | 2 | 2GB | 20GB HDD | ✅ Да | ~0.18 | ~130 |
| BACKUP-01 | 2 | 2GB | 30GB HDD | ✅ Да | ~0.20 | ~144 |
| **Итого** | | | | | **~1.28 руб/час** | **~924 руб/мес** |

> ⚠️ Цены ориентировочные, актуальные проверяйте в [калькуляторе Yandex Cloud](https://cloud.yandex.ru/calculator)
> 
> **Экономия:** ~70% за счёт прерываемых ВМ и HDD дисков

---

## Структура репозитория

```
diploma-project/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── vpc.tf
│   ├── security-groups.tf
│   └── compute.tf
├── ansible/
│   ├── site.yml
│   ├── inventory/
│   │   └── hosts.ini
│   ├── playbooks/
│   │   ├── nginx-lb.yml
│   │   ├── mediawiki.yml
│   │   ├── postgresql.yml
│   │   ├── pg-replication.yml
│   │   ├── zabbix.yml
│   │   └── backup.yml
│   └── roles/
├── docs/
│   ├── requirements.md
│   ├── architecture.md (схема)
│   ├── servers-config.md
│   ├── recovery-plan.md
│   └── diagrams/
├── scripts/
│   ├── backup-fs.sh
│   └── backup-db.sh
└── README.md
```

---
