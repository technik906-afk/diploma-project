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
|:---|:---|
| ☁️ **Облачный провайдер** | Yandex Cloud |
| 🐧 **ОС** | Ubuntu 22.04 LTS |
| 🌍 **Регион** | `ru-central1-a` |
| 🌐 **VPC** | `mediawiki-vpc` |
| ⏱️ **Тип ВМ** | Прерываемые (preemptible) |
| 💾 **Тип диска** | Сетевой HDD (network-hdd) |
| 🖥️ **Количество серверов** | **7** |

---

## Схема архитектуры

> 📐 Интерактивная схема: [`docs/diagrams/architecture.drawio`](diagrams/architecture.drawio)
> Открыть: [app.diagrams.net](https://app.diagrams.net/) → перетащить файл


---

## Конфигурация серверов

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Сервер</th>
      <th>Роль</th>
      <th>vCPU</th>
      <th>RAM</th>
      <th>Disk</th>
      <th>Preemptible</th>
      <th>Public IP</th>
      <th>Private IP</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td><strong>LB-01</strong></td>
      <td>Nginx Load Balancer</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>✅ 111.88.246.67</td>
      <td><code>10.0.1.10</code></td>
    </tr>
    <tr>
      <td>2</td>
      <td><strong>APP-01</strong></td>
      <td>MediaWiki Application</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.2.10</code></td>
    </tr>
    <tr>
      <td>3</td>
      <td><strong>APP-02</strong></td>
      <td>MediaWiki Application</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.2.11</code></td>
    </tr>
    <tr>
      <td>4</td>
      <td><strong>DB-01</strong></td>
      <td>PostgreSQL Primary</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.3.10</code></td>
    </tr>
    <tr>
      <td>5</td>
      <td><strong>DB-02</strong></td>
      <td>PostgreSQL Replica</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.3.11</code></td>
    </tr>
    <tr>
      <td>6</td>
      <td><strong>ZABBIX-01</strong></td>
      <td>Zabbix Server + Frontend</td>
      <td>2</td>
      <td>2 GB</td>
      <td>20 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.4.10</code></td>
    </tr>
    <tr>
      <td>7</td>
      <td><strong>BACKUP-01</strong></td>
      <td>Backup Storage</td>
      <td>2</td>
      <td>2 GB</td>
      <td>30 GB HDD</td>
      <td>✅</td>
      <td>❌</td>
      <td><code>10.0.5.10</code></td>
    </tr>
  </tbody>
</table>

---

## Сетевая схема

### VPC и подсети

```
VPC: mediawiki-vpc  •  CIDR: 10.0.0.0/16  •  Zone: ru-central1-a

┌──────────────────────────────────────────────────────────────────────┐
│  Подсеть        │ CIDR         │ Серверы           │ Назначение      │
├──────────────────────────────────────────────────────────────────────┤
│  lb-subnet      │ 10.0.1.0/24  │ LB-01             │ Балансировщик   │
│  app-subnet     │ 10.0.2.0/24  │ APP-01, APP-02    │ MediaWiki       │
│  db-subnet      │ 10.0.3.0/24  │ DB-01, DB-02      │ PostgreSQL      │
│  zabbix-subnet  │ 10.0.4.0/24  │ ZABBIX-01         │ Мониторинг      │
│  backup-subnet  │ 10.0.5.0/24  │ BACKUP-01         │ Бэкапы          │
└──────────────────────────────────────────────────────────────────────┘
```

### Схема подсетей

```
10.0.0.0/16
├── 10.0.1.0/24  ┃ LB-01      ┃ Public Gateway ┃ ← Интернет
├── 10.0.2.0/24  ┃ APP-01/02  ┃ Internal only  ┃ ← Только от LB
├── 10.0.3.0/24  ┃ DB-01/02   ┃ Internal only  ┃ ← Только от APP/BACKUP
├── 10.0.4.0/24  ┃ ZABBIX-01  ┃ Internal only  ┃ ← Только от LB (HTTP)
└── 10.0.5.0/24  ┃ BACKUP-01  ┃ Internal only  ┃ ← Только от APP/DB
```

---

## Security Groups

### 🔵 sg-lb — Балансировщик

<table>
  <thead>
    <tr>
      <th>Протокол</th>
      <th>Порт</th>
      <th>Направление</th>
      <th>Источник</th>
      <th>Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>TCP</td><td><strong>80</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>HTTP из интернета</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>443</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>HTTPS из интернета</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>22</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>SSH от администратора</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10050</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.4.0/24</code></td>
      <td>Zabbix Agent от ZABBIX-01</td>
    </tr>
    <tr>
      <td>ANY</td><td><strong>Все</strong></td>
      <td>⬆️ Outbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>Весь исходящий трафик</td>
    </tr>
  </tbody>
</table>

### 🟢 sg-app — Серверы приложений

<table>
  <thead>
    <tr>
      <th>Протокол</th>
      <th>Порт</th>
      <th>Направление</th>
      <th>Источник</th>
      <th>Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>TCP</td><td><strong>80</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code></td>
      <td>HTTP только от LB-01</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>22</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code></td>
      <td>SSH только через LB (jump-host)</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10050</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.4.0/24</code></td>
      <td>Zabbix Agent от ZABBIX-01</td>
    </tr>
    <tr>
      <td>ANY</td><td><strong>Все</strong></td>
      <td>⬆️ Outbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>Весь исходящий трафик</td>
    </tr>
  </tbody>
</table>

### 🔴 sg-db — База данных

<table>
  <thead>
    <tr>
      <th>Протокол</th>
      <th>Порт</th>
      <th>Направление</th>
      <th>Источник</th>
      <th>Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>TCP</td><td><strong>5432</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.2.0/24</code></td>
      <td>PostgreSQL от APP-серверов</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>5432</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.4.0/24</code></td>
      <td>PostgreSQL от ZABBIX-01</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>5432</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.5.0/24</code></td>
      <td>PostgreSQL от BACKUP-01</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>5432</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.3.0/24</code></td>
      <td>Репликация между DB-серверами</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>22</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code></td>
      <td>SSH только через LB (jump-host)</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10050</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.4.0/24</code></td>
      <td>Zabbix Agent от ZABBIX-01</td>
    </tr>
    <tr>
      <td>ANY</td><td><strong>Все</strong></td>
      <td>⬆️ Outbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>Весь исходящий трафик</td>
    </tr>
  </tbody>
</table>

### 🟡 sg-zabbix — Мониторинг

<table>
  <thead>
    <tr>
      <th>Протокол</th>
      <th>Порт</th>
      <th>Направление</th>
      <th>Источник</th>
      <th>Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>TCP</td><td><strong>80</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code></td>
      <td>HTTP только от LB (proxy)</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10050</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.0.0/8</code></td>
      <td>Zabbix Agent от всех внутренних</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10051</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.0.0/8</code></td>
      <td>Zabbix Trapper от всех внутренних</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>22</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code></td>
      <td>SSH только через LB (jump-host)</td>
    </tr>
    <tr>
      <td>ANY</td><td><strong>Все</strong></td>
      <td>⬆️ Outbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>Весь исходящий трафик</td>
    </tr>
  </tbody>
</table>

### 🟣 sg-backup — Бэкапы

<table>
  <thead>
    <tr>
      <th>Протокол</th>
      <th>Порт</th>
      <th>Направление</th>
      <th>Источник</th>
      <th>Описание</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>TCP</td><td><strong>22</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.1.0/24</code><br><code>10.0.2.0/24</code><br><code>10.0.3.0/24</code></td>
      <td>SSH от LB, APP и DB подсетей</td>
    </tr>
    <tr>
      <td>TCP</td><td><strong>10050</strong></td>
      <td>⬇️ Inbound</td>
      <td><code>10.0.4.0/24</code></td>
      <td>Zabbix Agent от ZABBIX-01</td>
    </tr>
    <tr>
      <td>ANY</td><td><strong>Все</strong></td>
      <td>⬆️ Outbound</td>
      <td><code>0.0.0.0/0</code></td>
      <td>Весь исходящий трафик</td>
    </tr>
  </tbody>
</table>

---

## Доступ к серверам

### SSH через jump-host (LB-01)

> ⚠️ **Только LB-01 имеет публичный IP.** Все остальные серверы доступны исключительно через SSH jump-host.

<table>
  <thead>
    <tr>
      <th>Сервер</th>
      <th>Команда подключения</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>LB-01</strong></td>
      <td><code>ssh -i ~/.ssh/yandex_cloud ubuntu@111.88.246.67</code></td>
    </tr>
    <tr>
      <td><strong>APP-01</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.2.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>APP-02</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.2.11 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>DB-01</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.3.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>DB-02</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.3.11 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>ZABBIX-01</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.4.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>BACKUP-01</strong></td>
      <td><code>ssh -J ubuntu@111.88.246.67 ubuntu@10.0.5.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
  </tbody>
</table>

---

## Terraform конфигурация

### Переменные (`variables.tf`)

```hcl
variable "region"          { default = "ru-central1-a" }
variable "vpc_name"        { default = "mediawiki-vpc" }
variable "cloud_id"        { type = string }
variable "folder_id"       { type = string }
variable "admin_ip"        { type = string }
variable "admin_ssh_keys"  { type = list(string) }
variable "service_account_key_file" { type = string, sensitive = true }
```

### Типы инстансов

```hcl
variable "instance_type" {
  default = {
    lb     = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    app    = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    db     = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    zabbix = { vcpu = 2, memory = 2, disk = 20, disk_type = "network-hdd", preemptible = true }
    backup = { vcpu = 2, memory = 2, disk = 30, disk_type = "network-hdd", preemptible = true }
  }
}
```

### Подсети

```hcl
variable "subnets" {
  default = {
    lb     = { cidr = "10.0.1.0/24", zone = "ru-central1-a", name = "lb-subnet" }
    app    = { cidr = "10.0.2.0/24", zone = "ru-central1-a", name = "app-subnet" }
    db     = { cidr = "10.0.3.0/24", zone = "ru-central1-a", name = "db-subnet" }
    zabbix = { cidr = "10.0.4.0/24", zone = "ru-central1-a", name = "zabbix-subnet" }
    backup = { cidr = "10.0.5.0/24", zone = "ru-central1-a", name = "backup-subnet" }
  }
}
```

---

## Ansible инвентори

### `~/.ssh/config` (SSH jump)

```ssh
Host yc-lb
    HostName 111.88.246.67
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

### `ansible/inventory/hosts.ini`

```ini
[lb]
lb-01 ansible_host=111.88.246.67

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
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3
```

---

## План работ по этапам

### Этап 0 — Подготовка инфраструктуры (Terraform)

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Задача</th>
      <th>Инструмент</th>
      <th>Артефакт</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>0.1</td><td>Создать VPC и 5 подсетей</td><td>Terraform</td><td><code>vpc.tf</code></td></tr>
    <tr><td>0.2</td><td>Настроить Security Groups (5 групп)</td><td>Terraform</td><td><code>security-groups.tf</code></td></tr>
    <tr><td>0.3</td><td>Создать 7 ВМ с нужными параметрами</td><td>Terraform</td><td><code>compute.tf</code></td></tr>
    <tr><td>0.4</td><td>Развернуть инфраструктуру</td><td>Terraform</td><td><code>terraform apply</code></td></tr>
  </tbody>
</table>

### Этап 1 — Проектирование и документация

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Задача</th>
      <th>Артефакт</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>1.1</td><td>Оформить требования по шаблону</td><td><code>docs/requirements.md</code></td></tr>
    <tr><td>1.2</td><td>Нарисовать схему архитектуры</td><td><code>docs/diagrams/architecture.png</code></td></tr>
    <tr><td>1.3</td><td>Описать план восстановления</td><td><code>docs/recovery-plan.md</code></td></tr>
  </tbody>
</table>

### Этап 2 — Развёртывание ПО (Ansible)

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Задача</th>
      <th>Серверы</th>
      <th>Роль Ansible</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>2.1</td><td>Установить Nginx (балансировщик)</td><td>LB-01</td><td><code>nginx-lb</code></td></tr>
    <tr><td>2.2</td><td>Установить MediaWiki + PHP</td><td>APP-01, APP-02</td><td><code>mediawiki</code></td></tr>
    <tr><td>2.3</td><td>Установить PostgreSQL + репликация</td><td>DB-01, DB-02</td><td><code>postgresql</code></td></tr>
    <tr><td>2.4</td><td>Установить Zabbix Server</td><td>ZABBIX-01</td><td><code>zabbix</code></td></tr>
    <tr><td>2.5</td><td>Настроить бэкапы + cron</td><td>BACKUP-01</td><td><code>backup</code></td></tr>
  </tbody>
</table>

### Этап 3 — Мониторинг (Zabbix)

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Задача</th>
      <th>Артефакт</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>3.1</td><td>Настроить мониторинг HTTP (код ответа, время)</td><td>Zabbix templates</td></tr>
    <tr><td>3.2</td><td>Добавить все 6 хостов в Zabbix</td><td>Zabbix config</td></tr>
  </tbody>
</table>

### Этап 4 — Отказоустойчивость (тестирование)

<table>
  <thead>
    <tr>
      <th>№</th>
      <th>Задача</th>
      <th>Подтверждение</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>4.1</td><td>Выключить APP-сервер → проверить работу</td><td>Скриншоты / видео</td></tr>
    <tr><td>4.2</td><td>Выключить DB-master → проверить переключение</td><td>Скриншоты / видео</td></tr>
    <tr><td>4.3</td><td>Восстановить директорию из бэкапа</td><td>Лог восстановления</td></tr>
    <tr><td>4.4</td><td>Восстановить БД из бэкапа</td><td>Лог восстановления</td></tr>
    <tr><td>4.5</td><td>Записать видео-презентацию</td><td>Видеофайл</td></tr>
  </tbody>
</table>

---

## Стоимость

> 💡 Прерываемые ВМ дешевле до **70%**, но могут быть остановлены облаком. Сетевые HDD дешевле SSD, но имеют меньшую производительность.

<table>
  <thead>
    <tr>
      <th>Сервер</th>
      <th>vCPU</th>
      <th>RAM</th>
      <th>Disk</th>
      <th>Preemptible</th>
      <th>Цена/час</th>
      <th>Цена/мес</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>LB-01</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>APP-01</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>APP-02</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>DB-01</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>DB-02</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>ZABBIX-01</td><td>2</td><td>2 GB</td><td>20 GB HDD</td><td>✅</td><td>~0.18 ₽</td><td>~130 ₽</td></tr>
    <tr><td>BACKUP-01</td><td>2</td><td>2 GB</td><td>30 GB HDD</td><td>✅</td><td>~0.20 ₽</td><td>~144 ₽</td></tr>
    <tr style="font-weight:bold; background:#f0f0f0;">
      <td colspan="5">ИТОГО</td>
      <td>~1.28 ₽/час</td>
      <td>~924 ₽/мес</td>
    </tr>
  </tbody>
</table>

> ⚠️ Цены ориентировочные. Актуальные цены проверяйте в [калькуляторе Yandex Cloud](https://cloud.yandex.ru/calculator)
>
> **Экономия:** ~70% за счёт прерываемых ВМ и HDD дисков

---

## Структура репозитория

```
diploma-project/
│
├── terraform/                    # Infrastructure as Code
│   ├── providers.tf              #   Провайдер Yandex Cloud
│   ├── variables.tf              #   Входные переменные
│   ├── main.tf                   #   Locals и data sources
│   ├── vpc.tf                    #   Сеть и подсети
│   ├── security-groups.tf        #   Правила файрвола (5 групп)
│   ├── compute.tf                #   7 виртуальных машин
│   └── outputs.tf                #   Выходные данные (IP, SSH-команды)
│
├── ansible/                      # Configuration Management
│   ├── ansible.cfg               #   Конфигурация Ansible
│   ├── site.yml                  #   Главный playbook
│   ├── inventory/
│   │   └── hosts.ini             #   Инвентори серверов
│   └── roles/
│       ├── nginx-lb/             #   Nginx балансировщик
│       ├── mediawiki/            #   MediaWiki + PHP
│       ├── postgresql/           #   PostgreSQL + репликация
│       ├── zabbix/               #   Zabbix Server + Agent
│       └── backup/               #   Скрипты бэкапов + cron
│
├── scripts/                      # Утилиты
│   ├── update-inventory.sh       #   Обновление inventory из Terraform
│   ├── backup-db.sh              #   Бэкап PostgreSQL
│   └── backup-fs.sh              #   Бэкап файловой системы
│
├── docs/                         # Документация
│   ├── requirements.md           #   Требования к проекту
│   ├── architecture.md           #   Архитектура системы
│   ├── infrastructure-plan.md    #   Полный план реализации (этот файл)
│   ├── servers-config.md         #   Детальная конфигурация серверов
│   ├── recovery-plan.md          #   План восстановления при сбоях
│   └── diagrams/                 #   Графические диаграммы
│
├── DEPLOY.md                     # Пошаговая инструкция развёртывания
└── README.md                     # Описание проекта
```

---
