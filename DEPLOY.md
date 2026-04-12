# 📘 Развёртывание MediaWiki в Yandex Cloud

> **Дипломный проект:** Высокодоступная инфраструктура MediaWiki с мониторингом и бэкапами

---

## Оглавление

1. Подготовка
2. Terraform — создание инфраструктуры
3. Ansible — настройка серверов
4. Настройка MediaWiki
5. Настройка Zabbix
6. Настройка бэкапов
7. Проверка работоспособности
8. Отказоустойчивость
9. Уничтожение инфраструктуры

---

## 1. Подготовка

### 1.1. Проверка зависимостей

Убедитесь, что установлены:

```bash
terraform -version   # >= 1.0
ansible --version    # >= 2.9
yc --version         # последняя версия провайдера
```

### 1.2. SSH-ключи

Если ещё нет — создайте:

```bash
ssh-keygen -t ed25519 -C "yandex-cloud" -f ~/.ssh/id_ed25519 -N ""
```

### 1.3. Файл переменных Terraform

Создайте `terraform/terraform.tfvars`:

```bash
cd terraform

# Узнайте ID каталога в облаке
FOLDER_ID=$(yc config get folder-id)

# Публичный ВАШ SSH-ключ для подключения к серверам
SSH_PUB=$(cat ~/.ssh/id_ed25519.pub)

cat > terraform.tfvars << EOF
cloud_id                 = "$(yc config get cloud-id)"
folder_id                = "${FOLDER_ID}"
service_account_key_file = "./key.json"
admin_ip                 = "0.0.0.0"
ssh_public_keys          = ["${SSH_PUB}"]
EOF
```

> ⚠️ Убедитесь, что `terraform.tfvars` и `key.json` в `.gitignore`.

---

## 2. Terraform — создание инфраструктуры

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

После завершения запишите внешний IP балансировщика:

```bash
terraform output -raw lb_public_ip
```

---

## 3. Ansible — настройка серверов

### 3.1. Обновление inventory

После `terraform apply` обновите IP-адреса серверов скриптом:

```bash
./scripts/update-inventory.sh
```

### 3.2. Проверка подключения

```bash
cd ansible
ansible all -m ping
```

### 3.3. Запуск Ansible

```bash
# Полный запуск (не рекомендуется)
ansible-playbook site.yml

# Или по ролям: (рекомендуется, лучше запускать по ролям и решать проблемы отдельно для каждой роли)
ansible-playbook site.yml --tags nginx
ansible-playbook site.yml --tags postgresql
ansible-playbook site.yml --tags mediawiki
ansible-playbook site.yml --tags zabbix
ansible-playbook site.yml --tags backup
```
# При успешном выполнении будет развернута и настроена вся инфраструктура, далее будет настройка сервисов непосредственно в веб интерфейсах


---

## 4. Настройка MediaWiki

### 4.1. Откройте установку

```
http://<LB_PUBLIC_IP>
```

### 4.2. Параметры подключения к БД

| Параметр | Значение |
|----------|----------|
| Тип БД | PostgreSQL |
| Хост | `10.0.3.10` |
| Имя БД | `my_wiki` |
| Логин | `wikiuser` |
| Пароль | `WikiPass2024!` |

### 4.2. Сохраните LocalSettings.php

Скачанный файл `LocalSettings.php` скопируйте на оба сервера приложений командой ниже (путь к файлу src измените на свой):

```bash
ansible app -m copy -a "src=./LocalSettings.php dest=/var/www/mediawiki/LocalSettings.php owner=www-data group=www-data mode=0644"
```

---

## 5. Настройка Zabbix

### 5.1. Установка локальной PostgreSQL и настройка

Zabbix развёрнут с настройкой на удалённую БД. Для работы с локальной:

```bash
# На zabbix-01 (через LB-01 jump-host)
LB=111.88.241.156
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo apt-get install -y postgresql postgresql-client php-pgsql"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo -u postgres psql -c \"CREATE USER zabbix WITH PASSWORD 'ZabbixPass2024!';\""
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo -u postgres psql -c \"CREATE DATABASE zabbix OWNER zabbix;\""
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo sed -i '1i host    zabbix          zabbix          127.0.0.1/32            md5' /etc/postgresql/*/main/pg_hba.conf"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo systemctl reload postgresql"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo gunzip -c /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | PGPASSWORD=ZabbixPass2024! psql -h 127.0.0.1 -U zabbix -d zabbix"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo sed -i 's/^DBHost=.*/DBHost=127.0.0.1/' /etc/zabbix/zabbix_server.conf"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo sed -i 's/^DBPassword=.*/DBPassword=ZabbixPass2024!/' /etc/zabbix/zabbix_server.conf"
ssh -J ubuntu@$LB ubuntu@10.0.4.10 "sudo systemctl restart zabbix-server apache2 postgresql"
```

### 5.2. Откройте веб-интерфейс

```
http://<LB_PUBLIC_IP>/zabbix
```

Логин: **Admin**, пароль: **zabbix**

### 5.2. Добавьте хосты

**Data collection → Hosts → Create host**

| Host name | IP | Templates |
|-----------|-----|-----------|
| LB-01 | `10.0.1.10` | Linux by Zabbix agent |
| APP-01 | `10.0.2.10` | Linux by Zabbix agent |
| APP-02 | `10.0.2.11` | Linux by Zabbix agent |
| DB-01 | `10.0.3.10` | Linux by Zabbix agent |
| DB-02 | `10.0.3.11` | Linux by Zabbix agent |
| BACKUP-01 | `10.0.5.10` | Linux by Zabbix agent |

> ⚠️ Для LB-01 используйте **внутренний IP** `10.0.1.10`, а не внешний.

---

## 6. Настройка бэкапов

Бэкапы настроены автоматически через cron:
- **БД** — ежедневно в 2:00 (`/opt/backup/backup-db.sh`)
- **Конфиги** — ежедневно в 3:00 (`/opt/backup/backup-fs.sh`)
- **Хранение** — 7 дней

Проверка:

```bash
LB=111.88.241.156
# Запуск вручную
ssh -J ubuntu@$LB ubuntu@10.0.5.10 "sudo /opt/backup/backup-db.sh"
ssh -J ubuntu@$LB ubuntu@10.0.5.10 "sudo /opt/backup/backup-fs.sh"

# Просмотр бэкапов
ssh -J ubuntu@$LB ubuntu@10.0.5.10 "sudo ls -lh /backup/mediawiki/db/"
ssh -J ubuntu@$LB ubuntu@10.0.5.10 "sudo ls -lh /backup/mediawiki/fs/"
```

---

## 7. Проверка работоспособности

### MediaWiki

```bash
LB_IP=$(cd terraform && terraform output -raw lb_public_ip)
curl -I http://${LB_IP}
# Ожидаемый статус: HTTP/1.1 301 или 200
```

### PostgreSQL репликация

```bash
LB=111.88.241.156
ssh -J ubuntu@$LB ubuntu@10.0.3.10 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"  # f (primary)
ssh -J ubuntu@$LB ubuntu@10.0.3.11 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"  # t (replica)
```

### Zabbix

Веб-интерфейс: `http://<LB_PUBLIC_IP>/zabbix`

### Бэкапы

```bash
LB=111.88.241.156
ssh -J ubuntu@$LB ubuntu@10.0.5.10 "sudo ls -lh /backup/mediawiki/db/"
```

---

## 8. Отказоустойчивость

### При отказе app-01

Nginx автоматически переключает трафик на app-02 через `max_fails=3 fail_timeout=30s`.

### При отказе db-01 (primary)

1. Повысьте replica до primary:
   ```bash
   LB=111.88.241.156
   ssh -J ubuntu@$LB ubuntu@10.0.3.11 "sudo pg_ctlcluster 14 main promote"
   ```
2. Обновите `LocalSettings.php` на app-серверах:
   ```bash
   ansible app -m lineinfile -a "path=/var/www/mediawiki/LocalSettings.php regexp='10.0.3.10' line='  [\"host\" => \"10.0.3.11\", ...],'"
   ansible app -m systemd -a "name=php8.1-fpm state=restarted"
   ```

### Восстановление репликации

После возврата db-01:

```bash
LB=111.88.241.156
ssh -J ubuntu@$LB ubuntu@10.0.3.10 "sudo systemctl stop postgresql && sudo rm -rf /var/lib/postgresql/14/main && sudo mkdir -p /var/lib/postgresql/14/main && sudo chown postgres:postgres /var/lib/postgresql/14/main && sudo -u postgres pg_basebackup -h 10.0.3.11 -D /var/lib/postgresql/14/main -U replicator -P -v -R && sudo chmod 700 /var/lib/postgresql/14/main && sudo systemctl start postgresql@14-main"
```

---

## 9. Уничтожение инфраструктуры

```bash
cd terraform
terraform destroy
```

---

## 📊 Архитектура

| # | Имя | Роль | Private IP | vCPU | RAM | Disk |
|---|-----|------|------------|------|-----|------|
| 1 | LB-01 | Nginx Load Balancer | 10.0.1.10 | 2 | 2 GB | 20 GB |
| 2 | APP-01 | MediaWiki | 10.0.2.10 | 2 | 2 GB | 20 GB |
| 3 | APP-02 | MediaWiki | 10.0.2.11 | 2 | 2 GB | 20 GB |
| 4 | DB-01 | PostgreSQL Primary | 10.0.3.10 | 2 | 2 GB | 20 GB |
| 5 | DB-02 | PostgreSQL Replica | 10.0.3.11 | 2 | 2 GB | 20 GB |
| 6 | ZABBIX-01 | Мониторинг | 10.0.4.10 | 2 | 2 GB | 20 GB |
| 7 | BACKUP-01 | Бэкапы | 10.0.5.10 | 2 | 2 GB | 30 GB |

---

## 🔗 Полезные команды

```bash
# Terraform
terraform plan / apply / destroy
terraform output

# Ansible
ansible all -m ping
ansible-playbook site.yml
ansible-playbook site.yml --tags mediawiki

# YC CLI
yc compute instance list
```
