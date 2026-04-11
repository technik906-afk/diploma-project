# Конфигурация серверов для MediaWiki Infrastructure

## Общая информация

| Параметр | Значение |
|:---|:---|
| ☁️ **Облачный провайдер** | Yandex Cloud |
| 🐧 **ОС** | Ubuntu 22.04 LTS |
| 🌍 **Регион** | `ru-central1-a` |
| 🌐 **VPC** | `mediawiki-vpc` |
| ⏱️ **Тип ВМ** | Прерываемые (preemptible) |
| 💾 **Тип диска** | Сетевой HDD (network-hdd) |

---

## Серверы

### 1. 🖥️ Балансировщик нагрузки — LB-01

<table>
  <tr><td><strong>Роль</strong></td><td>Nginx Load Balancer</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>20 GB (network-hdd)</td></tr>
  <tr><td><strong>Preemptible</strong></td><td>✅ Да</td></tr>
  <tr><td><strong>Public IP</strong></td><td>✅ 111.88.247.210</td></tr>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.1.10</code></td></tr>
</table>

**Порты:**

| Порт | Протокол | Источник | Описание |
|:---:|:---:|:---|:---|
| 80 | TCP | `0.0.0.0/0` | HTTP из интернета |
| 443 | TCP | `0.0.0.0/0` | HTTPS из интернета |
| 22 | TCP | `0.0.0.0/0` | SSH от администратора |

**ПО:** Nginx (upstream балансировка на APP-01/APP-02 + proxy на ZABBIX-01)

---

### 2. 🌐 Серверы приложений — APP-01, APP-02

<table>
  <tr><td><strong>Роль</strong></td><td>MediaWiki Application Server</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>20 GB (network-hdd)</td></tr>
  <tr><td><strong>Preemptible</strong></td><td>✅ Да</td></tr>
  <tr><td><strong>Public IP</strong></td><td>❌ Нет</td></tr>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.2.10</code> (APP-01), <code>10.0.2.11</code> (APP-02)</td></tr>
</table>

**Порты:**

| Порт | Протокол | Источник | Описание |
|:---:|:---:|:---|:---|
| 80 | TCP | `10.0.1.0/24` | HTTP только от LB-01 |
| 22 | TCP | `10.0.1.0/24` | SSH только через LB (jump-host) |

**ПО:**
- Nginx (локальный)
- MediaWiki 1.42
- PHP 8.x + расширения (intl, mbstring, xml, apcu, curl, gd, zip, json, mysql)
- Zabbix Agent

---

### 3. 🗄️ База данных PostgreSQL — DB-01, DB-02

<table>
  <tr><td><strong>Роль</strong></td><td>PostgreSQL Primary (DB-01) / Replica (DB-02)</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>20 GB (network-hdd)</td></tr>
  <tr><td><strong>Preemptible</strong></td><td>✅ Да</td></tr>
  <tr><td><strong>Public IP</strong></td><td>❌ Нет</td></tr>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.3.10</code> (DB-01), <code>10.0.3.11</code> (DB-02)</td></tr>
</table>

**Порты:**

| Порт | Протокол | Источник | Описание |
|:---:|:---:|:---|:---|
| 5432 | TCP | `10.0.2.0/24` | PostgreSQL от APP-серверов |
| 5432 | TCP | `10.0.4.0/24` | PostgreSQL от ZABBIX-01 |
| 5432 | TCP | `10.0.5.0/24` | PostgreSQL от BACKUP-01 |
| 5432 | TCP | `10.0.3.0/24` | Репликация между DB-серверами |
| 22 | TCP | `10.0.1.0/24` | SSH только через LB (jump-host) |

**ПО:**
- PostgreSQL 14+
- Streaming replication (DB-01 → DB-02)
- Zabbix Agent

---

### 4. 📊 Сервер мониторинга — ZABBIX-01

<table>
  <tr><td><strong>Роль</strong></td><td>Zabbix Server + Frontend</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>20 GB (network-hdd)</td></tr>
  <tr><td><strong>Preemptible</strong></td><td>✅ Да</td></tr>
  <tr><td><strong>Public IP</strong></td><td>❌ Нет (доступ через LB proxy)</td></tr>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.4.10</code></td></tr>
</table>

**Порты:**

| Порт | Протокол | Источник | Описание |
|:---:|:---:|:---|:---|
| 80 | TCP | `10.0.1.0/24` | HTTP только от LB (proxy) |
| 10050 | TCP | `10.0.0.0/8` | Zabbix Agent от всех хостов |
| 10051 | TCP | `10.0.0.0/8` | Zabbix Trapper от всех хостов |
| 22 | TCP | `10.0.1.0/24` | SSH только через LB (jump-host) |

**ПО:**
- Zabbix Server 6.x/7.x
- Zabbix Frontend (Apache + PHP)
- Zabbix Agent
- PostgreSQL (локальная БД для Zabbix)

---

### 5. 💾 Сервер резервного копирования — BACKUP-01

<table>
  <tr><td><strong>Роль</strong></td><td>Backup Storage Server</td></tr>
  <tr><td><strong>vCPU / RAM</strong></td><td>2 / 2 GB</td></tr>
  <tr><td><strong>Disk</strong></td><td>30 GB (network-hdd)</td></tr>
  <tr><td><strong>Preemptible</strong></td><td>✅ Да</td></tr>
  <tr><td><strong>Public IP</strong></td><td>❌ Нет</td></tr>
  <tr><td><strong>Private IP</strong></td><td><code>10.0.5.10</code></td></tr>
</table>

**Порты:**

| Порт | Протокол | Источник | Описание |
|:---:|:---:|:---|:---|
| 22 | TCP | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` | SSH от LB, APP, DB |

**ПО:** SSH Server, rsync, postgresql-client, Zabbix Agent

**Структура хранения бэкапов:**

```
/backup/
└── mediawiki/
    ├── db/           # Бэкапы базы данных (pg_dump)
    │   └── mediawiki_db_YYYYMMDD_HHMMSS.sql.gz
    └── fs/           # Бэкапы файловой системы (tar)
        └── mediawiki_fs_YYYYMMDD_HHMMSS.tar.gz

Политика хранения: 7 дней (cron: БД в 2:00, ФС в 3:00)
```

---

## Security Groups

### 🔵 sg-lb — Балансировщик

<table>
  <thead>
    <tr><th>Протокол</th><th>Порт</th><th>Направление</th><th>Источник</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr><td>TCP</td><td><strong>80</strong></td><td>⬇️ Inbound</td><td><code>0.0.0.0/0</code></td><td>HTTP из интернета</td></tr>
    <tr><td>TCP</td><td><strong>443</strong></td><td>⬇️ Inbound</td><td><code>0.0.0.0/0</code></td><td>HTTPS из интернета</td></tr>
    <tr><td>TCP</td><td><strong>22</strong></td><td>⬇️ Inbound</td><td><code>0.0.0.0/0</code></td><td>SSH от администратора</td></tr>
    <tr><td>TCP</td><td><strong>10050</strong></td><td>⬇️ Inbound</td><td><code>10.0.4.0/24</code></td><td>Zabbix Agent от ZABBIX-01</td></tr>
    <tr><td>ANY</td><td><strong>Все</strong></td><td>⬆️ Outbound</td><td><code>0.0.0.0/0</code></td><td>Весь исходящий трафик</td></tr>
  </tbody>
</table>

### 🟢 sg-app — Серверы приложений

<table>
  <thead>
    <tr><th>Протокол</th><th>Порт</th><th>Направление</th><th>Источник</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr><td>TCP</td><td><strong>80</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code></td><td>HTTP только от LB-01</td></tr>
    <tr><td>TCP</td><td><strong>22</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code></td><td>SSH только через LB (jump-host)</td></tr>
    <tr><td>TCP</td><td><strong>10050</strong></td><td>⬇️ Inbound</td><td><code>10.0.4.0/24</code></td><td>Zabbix Agent от ZABBIX-01</td></tr>
    <tr><td>ANY</td><td><strong>Все</strong></td><td>⬆️ Outbound</td><td><code>0.0.0.0/0</code></td><td>Весь исходящий трафик</td></tr>
  </tbody>
</table>

### 🔴 sg-db — База данных

<table>
  <thead>
    <tr><th>Протокол</th><th>Порт</th><th>Направление</th><th>Источник</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr><td>TCP</td><td><strong>5432</strong></td><td>⬇️ Inbound</td><td><code>10.0.2.0/24</code></td><td>PostgreSQL от APP-серверов</td></tr>
    <tr><td>TCP</td><td><strong>5432</strong></td><td>⬇️ Inbound</td><td><code>10.0.4.0/24</code></td><td>PostgreSQL от ZABBIX-01</td></tr>
    <tr><td>TCP</td><td><strong>5432</strong></td><td>⬇️ Inbound</td><td><code>10.0.5.0/24</code></td><td>PostgreSQL от BACKUP-01</td></tr>
    <tr><td>TCP</td><td><strong>5432</strong></td><td>⬇️ Inbound</td><td><code>10.0.3.0/24</code></td><td>Репликация между DB-серверами</td></tr>
    <tr><td>TCP</td><td><strong>22</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code></td><td>SSH только через LB (jump-host)</td></tr>
    <tr><td>TCP</td><td><strong>10050</strong></td><td>⬇️ Inbound</td><td><code>10.0.4.0/24</code></td><td>Zabbix Agent от ZABBIX-01</td></tr>
    <tr><td>ANY</td><td><strong>Все</strong></td><td>⬆️ Outbound</td><td><code>0.0.0.0/0</code></td><td>Весь исходящий трафик</td></tr>
  </tbody>
</table>

### 🟡 sg-zabbix — Мониторинг

<table>
  <thead>
    <tr><th>Протокол</th><th>Порт</th><th>Направление</th><th>Источник</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr><td>TCP</td><td><strong>80</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code></td><td>HTTP только от LB (proxy)</td></tr>
    <tr><td>TCP</td><td><strong>10050</strong></td><td>⬇️ Inbound</td><td><code>10.0.0.0/8</code></td><td>Zabbix Agent от всех внутренних</td></tr>
    <tr><td>TCP</td><td><strong>10051</strong></td><td>⬇️ Inbound</td><td><code>10.0.0.0/8</code></td><td>Zabbix Trapper от всех внутренних</td></tr>
    <tr><td>TCP</td><td><strong>22</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code></td><td>SSH только через LB (jump-host)</td></tr>
    <tr><td>ANY</td><td><strong>Все</strong></td><td>⬆️ Outbound</td><td><code>0.0.0.0/0</code></td><td>Весь исходящий трафик</td></tr>
  </tbody>
</table>

### 🟣 sg-backup — Бэкапы

<table>
  <thead>
    <tr><th>Протокол</th><th>Порт</th><th>Направление</th><th>Источник</th><th>Описание</th></tr>
  </thead>
  <tbody>
    <tr><td>TCP</td><td><strong>22</strong></td><td>⬇️ Inbound</td><td><code>10.0.1.0/24</code><br><code>10.0.2.0/24</code><br><code>10.0.3.0/24</code></td><td>SSH от LB, APP и DB подсетей</td></tr>
    <tr><td>TCP</td><td><strong>10050</strong></td><td>⬇️ Inbound</td><td><code>10.0.4.0/24</code></td><td>Zabbix Agent от ZABBIX-01</td></tr>
    <tr><td>ANY</td><td><strong>Все</strong></td><td>⬆️ Outbound</td><td><code>0.0.0.0/0</code></td><td>Весь исходящий трафик</td></tr>
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

### Визуальная схема подсетей

```
10.0.0.0/16
├── 10.0.1.0/24  ┃ LB-01      ┃ Public Gateway ┃ ← Интернет (HTTP/HTTPS)
├── 10.0.2.0/24  ┃ APP-01/02  ┃ Internal only  ┃ ← Только от LB-01
├── 10.0.3.0/24  ┃ DB-01/02   ┃ Internal only  ┃ ← Только от APP/BACKUP
├── 10.0.4.0/24  ┃ ZABBIX-01  ┃ Internal only  ┃ ← Только от LB (HTTP)
└── 10.0.5.0/24  ┃ BACKUP-01  ┃ Internal only  ┃ ← Только от APP/DB
```

---

## Доступ к серверам

### SSH через jump-host (LB-01)

> ⚠️ **Только LB-01 имеет публичный IP.** Все остальные серверы доступны исключительно через SSH jump-host.

<table>
  <thead>
    <tr><th>Сервер</th><th>Private IP</th><th>Команда подключения</th></tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>LB-01</strong></td>
      <td><code>10.0.1.10</code></td>
      <td><code>ssh -i ~/.ssh/yandex_cloud ubuntu@111.88.247.210</code></td>
    </tr>
    <tr>
      <td><strong>APP-01</strong></td>
      <td><code>10.0.2.10</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.2.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>APP-02</strong></td>
      <td><code>10.0.2.11</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.2.11 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>DB-01</strong></td>
      <td><code>10.0.3.10</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.3.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>DB-02</strong></td>
      <td><code>10.0.3.11</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.3.11 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>ZABBIX-01</strong></td>
      <td><code>10.0.4.10</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.4.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
    <tr>
      <td><strong>BACKUP-01</strong></td>
      <td><code>10.0.5.10</code></td>
      <td><code>ssh -J ubuntu@111.88.247.210 ubuntu@10.0.5.10 -i ~/.ssh/yandex_cloud</code></td>
    </tr>
  </tbody>
</table>

**Преимущества:**
- 💰 Экономия ~22 ₽/мес (6 дополнительных IP не нужны)
- 🔒 Безопаснее — единственная точка входа, меньшая поверхность атаки

---

## Стоимость (ориентировочно)

> 💡 Прерываемые ВМ дешевле до **70%**. Сетевые HDD дешевле SSD в 2-3 раза.

<table>
  <thead>
    <tr><th>Сервер</th><th>vCPU</th><th>RAM</th><th>Disk</th><th>Preemptible</th><th>Цена/час</th><th>Цена/мес</th></tr>
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

> ⚠️ Цены ориентировочные. Актуальные — в [калькуляторе Yandex Cloud](https://cloud.yandex.ru/calculator)

---

## Рекомендации по экономии

### Прерываемые ВМ (Preemptible)

| ✅ Преимущества | ⚠️ Риски |
|:---|:---|
| До 70% дешевле постоянных ВМ | Облако может забрать ВМ при нехватке ресурсов |
| Подходит для тестовых/демо сред | Максимальное время жизни — 24 часа |

**Митигация рисков:**
- APP-серверы — 2 экземпляра, при падении одного трафик идёт на другой
- DB — репликация master/slave, при падении master переключаемся на replica
- Terraform скрипты позволяют быстро пересоздать инфраструктуру

### Сетевые HDD

| ✅ Преимущества | ⚠️ Ограничения |
|:---|:---|
| Дешевле SSD в 2-3 раза | Меньше IOPS (до 6000 против 15000+ у SSD) |
| Достаточно для демо нагрузок | Выше задержки |

**Митигация ограничений:**
- Для БД используем репликацию
- Регулярные бэкапы на отдельный диск

---

## Следующие шаги

| # | Этап | Статус |
|:---:|:---|:---:|
| 1 | Конфигурация серверов | ✅ Готово |
| 2 | Terraform конфигурация | ✅ Готово |
| 3 | Ansible Playbooks | ✅ Готово |
| 4 | Документация | ✅ Готово |
| 5 | Отказоустойчивость (тесты) | ⏳ В процессе |
