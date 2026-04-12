# MediaWiki Infrastructure in Yandex Cloud

Дипломный проект по развёртыванию MediaWiki в Yandex Cloud с использованием подходов Infrastructure as Code (IaC).

## 📋 Описание проекта

Проект включает развёртывание высокодоступной инфраструктуры для MediaWiki с:
- Балансировкой нагрузки (Nginx)
- Двумя серверами приложений MediaWiki
- PostgreSQL кластером (Primary + Replica)
- Мониторингом (Zabbix)
- Сервером резервного копирования

## 🏗️ Архитектура

```
Пользователи → LB-01 (Nginx) → APP-01/APP-02 (MediaWiki) → DB-01/DB-02 (PostgreSQL)
                                           ↓
                                    ZABBIX-01 (мониторинг)
                                           ↓
                                    BACKUP-01 (бэкапы)
```

## 📦 Структура репозитория

```
diploma-project/
├── terraform/              # Terraform конфигурация для Yandex Cloud
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── vpc.tf
│   ├── security-groups.tf
│   ├── compute.tf
│   └── outputs.tf
├── ansible/                # Ansible playbooks для настройки серверов
│   ├── inventory/
│   │   └── hosts.ini
│   ├── roles/
│   │   ├── nginx-lb/
│   │   ├── mediawiki/
│   │   ├── postgresql/
│   │   ├── zabbix/
│   │   └── backup/
│   ├── ansible.cfg
│   └── site.yml
├── scripts/                # Скрипты для автоматизации
│   ├── update-inventory.sh
│   ├── backup-fs.sh
│   └── backup-db.sh
├── DEPLOY.md               # Подробная инструкция по развёртыванию
└── README.md
```

## 🚀 Быстрый старт

Подробная инструкция: [DEPLOY.md](DEPLOY.md)

### Кратко:

```bash
# 1. Terraform
cd terraform
terraform init && terraform apply

# 2. Update inventory
./scripts/update-inventory.sh

# 3. Ansible
cd ../ansible
ansible-playbook site.yml

# 4. MediaWiki setup
# Откройте http://111.88.241.156 в браузере

# 5. Zabbix setup
# См. DEPLOY.md раздел 5
```

## 💰 Стоимость

Все виртуальные машины используют прерываемые инстансы и сетевые HDD для экономии:

| Сервер | vCPU | RAM | Disk |
|--------|------|-----|------|
| LB-01 | 2 | 2GB | 20GB |
| APP-01, APP-02 | 2 | 2GB | 20GB |
| DB-01, DB-02 | 2 | 2GB | 20GB |
| ZABBIX-01 | 2 | 2GB | 20GB |
| BACKUP-01 | 2 | 2GB | 30GB |


## 🔐 Безопасность

- SSH доступ только через jump-host (LB-01)
- Security groups ограничивают трафик между компонентами
- Все серверы в отдельных подсетях
- Пароли БД хранятся в переменных Ansible (не в репозитории)