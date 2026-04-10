# Архитектура инфраструктуры MediaWiki

## Обзор

Инфраструктура развёрнута в **Yandex Cloud** и состоит из **7 виртуальных машин**, объединённых в единую сеть VPC с изолированными подсетями и правилами файрвола.

---

## Схема архитектуры

> 📐 Интерактивная схема: [`docs/diagrams/architecture.drawio`](diagrams/architecture.drawio)
> Открыть: [app.diagrams.net](https://app.diagrams.net/) → перетащить файл


---

## Компоненты

### 1. 🖥️ Балансировщик нагрузки — LB-01

<table>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.1.10</code></td></tr>
  <tr><td><strong>Public IP</strong></td><td><code>111.88.246.67</code></td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>ПО</strong></td><td>Nginx (upstream балансировка)</td></tr>
  <tr><td><strong>Порты</strong></td><td>80 (HTTP), 443 (HTTPS), 22 (SSH)</td></tr>
</table>

**Функции:**
- 🔄 Распределение HTTP-трафика между APP-01 и APP-02 (Nginx upstream)
- 🔀 Proxy для Zabbix Frontend (`/zabbix` → ZABBIX-01:80)
- 🔐 SSH jump-host для доступа к внутренней сети
- 🚪 Единственная точка входа из интернета

---

### 2. 🌐 Серверы приложений — APP-01, APP-02

<table>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.2.10</code> (APP-01), <code>10.0.2.11</code> (APP-02)</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>ПО</strong></td><td>MediaWiki 1.42, PHP 8.x, Nginx</td></tr>
  <tr><td><strong>Порты</strong></td><td>80 (HTTP от LB), 22 (SSH от LB)</td></tr>
</table>

**Функции:**
- 📄 Хостинг MediaWiki (веб-интерфейс вики)
- ⚡ Обработка PHP-запросов через PHP-FPM
- 🔗 Подключение к PostgreSQL (DB-01 primary)

---

### 3. 🗄️ Серверы базы данных — DB-01, DB-02

<table>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.3.10</code> (DB-01 Master), <code>10.0.3.11</code> (DB-02 Replica)</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>ПО</strong></td><td>PostgreSQL 14+</td></tr>
  <tr><td><strong>Порты</strong></td><td>5432 (PostgreSQL), 22 (SSH от LB)</td></tr>
</table>

**Функции:**
- 💾 Хранение данных MediaWiki (БД `my_wiki`)
- 🔄 Streaming replication: DB-01 (Master) → DB-02 (Replica)
- 🛡️ Возможность переключения на реплику при отказе мастера

---

### 4. 📊 Сервер мониторинга — ZABBIX-01

<table>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.4.10</code></td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>ПО</strong></td><td>Zabbix Server, Zabbix Frontend (Apache + PHP), Zabbix Agent, PostgreSQL (локальная)</td></tr>
  <tr><td><strong>Порты</strong></td><td>80 (Web от LB), 10050/10051 (Zabbix), 22 (SSH от LB)</td></tr>
</table>

**Функции:**
- 📈 Мониторинг доступности сервисов (HTTP, PostgreSQL, Nginx)
- 📊 Сбор метрик производительности (CPU, RAM, Disk)
- 🔔 Оповещения о проблемах

---

### 5. 💾 Сервер резервного копирования — BACKUP-01

<table>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.5.10</code></td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>30 GB (увеличенный диск для бэкапов)</td></tr>
  <tr><td><strong>ПО</strong></td><td>rsync, postgresql-client, SSH</td></tr>
  <tr><td><strong>Порты</strong></td><td>22 (SSH от APP/DB)</td></tr>
</table>

**Функции:**
- 💾 Хранение бэкапов ФС и БД
- ⏰ Автоматические бэкапы по cron (БД в 2:00, ФС в 3:00)
- 📅 Политика хранения: 7 дней

---

## Сетевая архитектура

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

### Визуальная схема подсетей

```
10.0.0.0/16
├── 10.0.1.0/24  ┃ LB-01      ┃ Public Gateway ┃ ← Интернет (HTTP/HTTPS)
├── 10.0.2.0/24  ┃ APP-01/02  ┃ Internal only  ┃ ← Только от LB-01
├── 10.0.3.0/24  ┃ DB-01/02   ┃ Internal only  ┃ ← Только от APP/BACKUP
├── 10.0.4.0/24  ┃ ZABBIX-01  ┃ Internal only  ┃ ← Только от LB (HTTP)
└── 10.0.5.0/24  ┃ BACKUP-01  ┃ Internal only  ┃ ← Только от APP/DB
```

### Security Groups

<table>
  <thead>
    <tr><th>Группа</th><th>Серверы</th><th>Входящие правила</th></tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>🔵 sg-lb</strong></td>
      <td>LB-01</td>
      <td>HTTP/HTTPS из интернета, SSH от админа, Zabbix Agent от ZABBIX</td>
    </tr>
    <tr>
      <td><strong>🟢 sg-app</strong></td>
      <td>APP-01, APP-02</td>
      <td>HTTP от LB, SSH от LB, Zabbix Agent от ZABBIX</td>
    </tr>
    <tr>
      <td><strong>🔴 sg-db</strong></td>
      <td>DB-01, DB-02</td>
      <td>PostgreSQL от APP/BACKUP/ZABBIX, репликация внутри DB, SSH от LB, Zabbix Agent</td>
    </tr>
    <tr>
      <td><strong>🟡 sg-zabbix</strong></td>
      <td>ZABBIX-01</td>
      <td>HTTP от LB, Zabbix Agent/Trapper от внутренних, SSH от LB</td>
    </tr>
    <tr>
      <td><strong>🟣 sg-backup</strong></td>
      <td>BACKUP-01</td>
      <td>SSH от LB/APP/DB, Zabbix Agent от ZABBIX</td>
    </tr>
  </tbody>
</table>

---

## Потоки трафика

<table>
  <thead>
    <tr><th>№</th><th>Поток</th><th>Протокол</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>👤 → LB-01 → APP → DB</td>
      <td>HTTP → TCP:5432</td>
      <td>Пользователь открывает MediaWiki в браузере</td>
    </tr>
    <tr>
      <td>2</td>
      <td>🔑 → LB-01 → Все серверы</td>
      <td>SSH (jump)</td>
      <td>Админ подключается через jump-host</td>
    </tr>
    <tr>
      <td>3</td>
      <td>Все серверы → ZABBIX-01</td>
      <td>TCP:10050/10051</td>
      <td>Zabbix Agent собирает метрики</td>
    </tr>
    <tr>
      <td>4</td>
      <td>DB-01 / APP-01 → BACKUP-01</td>
      <td>SSH/rsync</td>
      <td>Автоматические бэкапы по cron</td>
    </tr>
    <tr>
      <td>5</td>
      <td>DB-01 → DB-02</td>
      <td>TCP:5432 (WAL)</td>
      <td>Streaming replication</td>
    </tr>
  </tbody>
</table>

---

## Инфраструктура как код (IaC)

### Terraform

| Файл | Описание |
|:---|:---|
| `providers.tf` | Провайдер Yandex Cloud (`yandex-cloud/yandex ~> 0.129`) |
| `variables.tf` | Входные переменные (cloud_id, folder_id, SSH-ключи, конфигурации) |
| `main.tf` | Locals (метки, образ Ubuntu), data sources |
| `vpc.tf` | VPC сеть + 5 подсетей |
| `security-groups.tf` | 5 security groups с правилами ingress/egress |
| `compute.tf` | 7 виртуальных машин (LB, APP×2, DB×2, ZABBIX, BACKUP) |
| `outputs.tf` | Выходные данные: IP-адреса, SSH-команды |

### Ansible

| Файл/Папка | Описание |
|:---|:---|
| `ansible.cfg` | Конфигурация Ansible (inventory, SSH, кэширование) |
| `site.yml` | Главный playbook (5 ролей) |
| `inventory/hosts.ini` | Инвентори серверов с IP и ProxyJump |
| `roles/nginx-lb/` | Nginx балансировщик на LB-01 |
| `roles/mediawiki/` | MediaWiki + PHP на APP-серверах |
| `roles/postgresql/` | PostgreSQL + репликация на DB-серверах |
| `roles/zabbix/` | Zabbix Server + Frontend + Agent |
| `roles/backup/` | Скрипты бэкапов + cron на BACKUP-01 |

---

## Экономия ресурсов

<table>
  <thead>
    <tr><th>Мера</th><th>Экономия</th><th>Примечание</th></tr>
  </thead>
  <tbody>
    <tr><td>Прерываемые ВМ</td><td>~60-70%</td><td>Все 7 серверов</td></tr>
    <tr><td>HDD диски</td><td>~50-60%</td><td>Вместо SSD</td></tr>
    <tr><td>Минимальная конфигурация</td><td>—</td><td>2 vCPU / 2 GB RAM</td></tr>
    <tr style="font-weight:bold; background:#f0f0f0;">
      <td>Итого</td>
      <td>~70%</td>
      <td>~924 руб/мес</td>
    </tr>
  </tbody>
</table>

---

## Масштабирование

### Горизонтальное (приложение)
- ➕ Добавление APP-серверов
- 📝 Обновление конфигурации Nginx upstream

### Вертикальное (ресурсы)
- ⬆️ Увеличение vCPU/RAM через Terraform
- 💾 Увеличение дискового пространства

### База данных
- ➕ Добавление реплик для чтения
- 🔀 Шардинг при необходимости
