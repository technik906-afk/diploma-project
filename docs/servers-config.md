# Конфигурация серверов для MediaWiki Infrastructure

## Общая информация

| Параметр | Значение |
|----------|----------|
| Облачный провайдер | Yandex Cloud |
| ОС | Ubuntu 22.04 LTS |
| Регион | ru-central1-a |
| VPC | mediawiki-vpc |
| Тип ВМ | Прерываемые (preemptible) |
| Тип диска | Сетевой HDD (network-hdd) |

---

## Серверы

### 1. Балансировщик нагрузки (LB-01)

| Параметр | Значение |
|----------|----------|
| **Роль** | Nginx Load Balancer |
| **vCPU** | 2 |
| **RAM** | 2 GB |
| **Disk** | 20 GB (network-hdd) |
| **Прерываемая ВМ** | Да |
| **Публичный IP** | Да |
| **Частный IP** | 10.0.1.10 |

**Порты:**
- 80/tcp — HTTP (входящий)
- 443/tcp — HTTPS (входящий)
- 22/tcp — SSH (входящий, admin only)

**Устанавливаемое ПО:**
- Nginx (upstream балансировка)

---

### 2. Приложение MediaWiki (APP-01, APP-02)

| Параметр | Значение |
|----------|----------|
| **Роль** | MediaWiki Application Server |
| **vCPU** | 2 |
| **RAM** | 2 GB |
| **Disk** | 20 GB (network-hdd) |
| **Прерываемая ВМ** | Да |
| **Публичный IP** | Нет |
| **Частный IP** | 10.0.2.10 (APP-01), 10.0.2.11 (APP-02) |

**Порты:**
- 80/tcp — HTTP (только от LB-01)
- 22/tcp — SSH (входящий, admin only)

**Устанавливаемое ПО:**
- Nginx (локальный)
- MediaWiki 1.42
- PHP 8.x + расширения (intl, mbstring, xml, apcu, curl)
- Zabbix Agent

---

### 3. База данных PostgreSQL (DB-01, DB-02)

| Параметр | Значение |
|----------|----------|
| **Роль** | PostgreSQL Primary (DB-01) / Replica (DB-02) |
| **vCPU** | 2 |
| **RAM** | 2 GB |
| **Disk** | 20 GB (network-hdd) |
| **Прерываемая ВМ** | Да |
| **Публичный IP** | Нет |
| **Частный IP** | 10.0.3.10 (DB-01), 10.0.3.11 (DB-02) |

**Порты:**
- 5432/tcp — PostgreSQL (только от APP-01, APP-02, BACKUP-01)
- 22/tcp — SSH (входящий, admin only)

**Устанавливаемое ПО:**
- PostgreSQL 14+
- pg_dump
- Zabbix Agent
- Репликация (streaming replication)

---

### 4. Сервер мониторинга (ZABBIX-01)

| Параметр | Значение |
|----------|----------|
| **Роль** | Zabbix Server + Frontend |
| **vCPU** | 2 |
| **RAM** | 2 GB |
| **Disk** | 20 GB (network-hdd) |
| **Прерываемая ВМ** | Да |
| **Публичный IP** | Да (для доступа к веб-интерфейсу) |
| **Частный IP** | 10.0.4.10 |

**Порты:**
- 80/tcp — HTTP (Zabbix Frontend)
- 10050/tcp — Zabbix Agent (входящий от всех хостов)
- 10051/tcp — Zabbix Trapper (входящий)
- 22/tcp — SSH (входящий, admin only)

**Устанавливаемое ПО:**
- Zabbix Server 6.x/7.x
- Zabbix Frontend (Apache/Nginx + PHP)
- Zabbix Agent
- PostgreSQL (локальная БД для Zabbix)

---

### 5. Сервер резервного копирования (BACKUP-01)

| Параметр | Значение |
|----------|----------|
| **Роль** | Backup Storage Server |
| **vCPU** | 2 |
| **RAM** | 2 GB |
| **Disk** | 30 GB (network-hdd, дополнительный диск для бэкапов) |
| **Прерываемая ВМ** | Да |
| **Публичный IP** | Нет |
| **Частный IP** | 10.0.5.10 |

**Порты:**
- 22/tcp — SSH (входящий, только от DB-01, APP-01 для бэкапов)

**Устанавливаемое ПО:**
- SSH Server
- rsync
- Zabbix Agent

**Структура хранения бэкапов:**
```
/backup/
├── mediawiki/
│   ├── fs/           # Бэкапы файловой системы
│   └── db/           # Бэкапы базы данных
└── retention.conf    # Политика хранения (7 дней)
```

---

## Security Groups

### sg-lb
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP | Inbound | 80 | 0.0.0.0/0 |
| HTTPS | Inbound | 443 | 0.0.0.0/0 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-app
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP from LB | Inbound | 80 | 10.0.1.10 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-db
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| PostgreSQL from APP | Inbound | 5432 | 10.0.2.0/24 |
| PostgreSQL from BACKUP | Inbound | 5432 | 10.0.5.10 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-zabbix
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| HTTP | Inbound | 80 | 0.0.0.0/0 |
| Zabbix Agent | Inbound | 10050 | 10.0.0.0/8 |
| Zabbix Trapper | Inbound | 10051 | 10.0.0.0/8 |
| SSH | Inbound | 22 | Admin IP |
| All Outbound | Outbound | All | 0.0.0.0/0 |

### sg-backup
| Правило | Направление | Порт | Источник |
|---------|-------------|------|----------|
| SSH from DB, APP | Inbound | 22 | 10.0.2.0/24, 10.0.3.0/24 |
| All Outbound | Outbound | All | 0.0.0.0/0 |

---

## Сетевая схема

```
VPC: mediawiki-vpc (10.0.0.0/16)

Подсети:
┌─────────────────────────────────────────────────────────────┐
│ Подсеть         | CIDR        | Назначение                  │
├─────────────────────────────────────────────────────────────┤
│ lb-subnet       | 10.0.1.0/24 | Балансировщик               │
│ app-subnet      | 10.0.2.0/24 | Приложение MediaWiki        │
│ db-subnet       | 10.0.3.0/24 | База данных PostgreSQL      │
│ zabbix-subnet   | 10.0.4.0/24 | Мониторинг Zabbix           │
│ backup-subnet   | 10.0.5.0/24 | Сервер резервного копирования│
└─────────────────────────────────────────────────────────────┘
```

---

## Переменные для Terraform

```hcl
# variables.tf
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

## Инвентори для Ansible

```ini
# ansible/inventory/hosts.ini
[lb]
lb-01 ansible_host=10.0.1.10

[app]
app-01 ansible_host=10.0.2.10
app-02 ansible_host=10.0.2.11

[db]
db-01 ansible_host=10.0.3.10 role=primary
db-02 ansible_host=10.0.3.11 role=replica

[zabbix]
zabbix-01 ansible_host=10.0.4.10

[backup]
backup-01 ansible_host=10.0.5.10

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/yandex_cloud
ansible_python_interpreter=/usr/bin/python3
```

---

## Стоимость (ориентировочно)

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

> ⚠️ Цены ориентировочные, актуальные цены проверяйте в [калькуляторе Yandex Cloud](https://cloud.yandex.ru/calculator)
> 
> **Экономия:** ~70% за счёт прерываемых ВМ и HDD дисков

---

## Рекомендации по экономии

### Прерываемые ВМ (Preemptible)

**Преимущества:**
- До 70% дешевле постоянных ВМ
- Подходит для тестовых и демонстрационных сред

**Риски:**
- Облако может забрать ВМ в любой момент (обычно при нехватке ресурсов)
- Максимальное время жизни — 24 часа, затем ВМ перезапускается

**Митигация:**
- Все ВМ прерываемые — инфраструктура поднимается на время демонстрации/тестов
- APP-серверы — 2 экземпляра, при падении одного трафик идёт на другой
- DB — репликация master/slave, при падении master переключаемся на replica
- Terraform скрипты позволяют быстро пересоздать инфраструктуру

### Сетевые HDD

**Преимущества:**
- Дешевле SSD в 2-3 раза
- Достаточно для демонстрационных нагрузок

**Ограничения:**
- Меньше IOPS (до 6000 против 15000+ у SSD)
- Выше задержки

**Митигация:**
- Для БД используем репликацию
- Регулярные бэкапы на отдельный диск

---

## Доступ к серверам

### Вариант 1: SSH через jump-host (рекомендуется)

Только LB-01 имеет публичный IP. К остальным ВМ подключаемся через него:

```bash
# К LB-01 напрямую
ssh -i ~/.ssh/yandex_cloud ubuntu@<lb-public-ip>

# К APP-01 через LB-01 (SSH jump)
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.2.10

# К DB-01 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.3.10

# К ZABBIX-01 через LB-01
ssh -i ~/.ssh/yandex_cloud -J ubuntu@<lb-public-ip> ubuntu@10.0.4.10
```

**Преимущества:**
- Экономия (~22 руб/мес за 6 дополнительных IP)
- Безопаснее (меньше поверхность атаки)

### Вариант 2: Публичные IP на всех ВМ

Если нужен прямой доступ к каждой ВМ без туннелирования:

| Сервер | Публичный IP |
|--------|--------------|
| LB-01 | Да |
| APP-01 | Да |
| APP-02 | Да |
| DB-01 | Да |
| DB-02 | Да |
| ZABBIX-01 | Да |
| BACKUP-01 | Да |

**Дополнительная стоимость:** ~0.03 руб/час за каждый IP ≈ **22 руб/мес за 6 дополнительных IP**

---

## Следующие шаги

1. ✅ Конфигурация серверов — **готово**
2. ⏳ Terraform конфигурация
3. ⏳ Ansible Playbooks
4. ⏳ Документация (requirements, recovery plan)
