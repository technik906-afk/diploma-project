# MediaWiki Infrastructure in Yandex Cloud

Дипломный проект по развёртыванию MediaWiki в Yandex Cloud с использованием подходов Infrastructure as Code (IaC).

## 📋 Описание проекта

Проект включает развёртывание высокодоступной инфраструктуры для MediaWiki с:
- Балансировкой нагрузки (Nginx)
- Двумя серверами приложений MediaWiki
- PostgreSQL кластером (Master + Replica)
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
├── terraform/           # Terraform конфигурация для Yandex Cloud
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── vpc.tf
│   ├── security-groups.tf
│   ├── compute.tf
│   └── outputs.tf
├── ansible/             # Ansible playbooks для настройки серверов
│   ├── inventory/
│   │   └── hosts.ini
│   ├── playbooks/
│   │   ├── nginx-lb.yml
│   │   ├── mediawiki.yml
│   │   ├── postgresql.yml
│   │   ├── pg-replication.yml
│   │   ├── zabbix.yml
│   │   └── backup.yml
│   └── site.yml
├── docs/                # Документация
│   ├── requirements.md
│   ├── architecture.md
│   ├── servers-config.md
│   ├── recovery-plan.md
│   └── diagrams/
├── scripts/             # Скрипты для бэкапов
│   ├── backup-fs.sh
│   └── backup-db.sh
└── README.md
```

## 🚀 Быстрый старт

### Предварительные требования

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.9
- [YC CLI](https://cloud.yandex.ru/docs/cli/quickstart)
- Аккаунт в Yandex Cloud

### 1. Клонирование репозитория

```bash
git clone https://github.com/technik906-afk/diploma-project.git
cd diploma-project
```

### 2. Настройка Yandex Cloud

```bash
# Инициализация профиля YC Cloud
yc init

# Создание сервисного аккаунта для Terraform
yc iam service-account create --name terraform-sa
yc iam service-account key create --service-account-name terraform-sa --output authorized_key.json
yc resource-manager folder add-access-binding <folder-id> --role editor --service-account-name terraform-sa
```

### 3. Развёртывание инфраструктуры (Terraform)

```bash
cd terraform

# Инициализация Terraform
terraform init

# Просмотр плана изменений
terraform plan

# Применение конфигурации
terraform apply
```

### 4. Настройка серверов (Ansible)

```bash
cd ../ansible

# Проверка подключения
ansible all -m ping

# Запуск всех playbooks
ansible-playbook site.yml

# Или выборочно
ansible-playbook playbooks/nginx-lb.yml
ansible-playbook playbooks/mediawiki.yml
ansible-playbook playbooks/postgresql.yml
```

## 💰 Стоимость

Все виртуальные машины используют прерываемые инстансы и сетевые HDD для экономии:

| Сервер | vCPU | RAM | Disk | Цена/мес (руб) |
|--------|------|-----|------|----------------|
| LB-01 | 2 | 2GB | 20GB | ~130 |
| APP-01, APP-02 | 2 | 2GB | 20GB | ~260 |
| DB-01, DB-02 | 2 | 2GB | 20GB | ~260 |
| ZABBIX-01 | 2 | 2GB | 20GB | ~130 |
| BACKUP-01 | 2 | 2GB | 30GB | ~144 |
| **Итого** | | | | **~924 руб/мес** |

> ⚠️ Цены ориентировочные. Актуальные цены проверяйте в [калькуляторе Yandex Cloud](https://cloud.yandex.ru/calculator)

## 📚 Документация

- [Требования к инфраструктуре](docs/requirements.md)
- [Конфигурация серверов](docs/servers-config.md)
- [Схема архитектуры](docs/architecture.md)
- [План восстановления](docs/recovery-plan.md)

## 🔐 Безопасность

- SSH доступ только через jump-host (LB-01)
- Security groups ограничивают трафик между компонентами
- Пароли БД хранятся в Ansible Vault (не в репозитории)

## 👤 Автор

technik906-afk

## 📄 Лицензия

MIT
