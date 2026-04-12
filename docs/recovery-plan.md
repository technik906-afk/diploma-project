# План восстановления инфраструктуры MediaWiki

> 🔑 **Важно:** Все серверы кроме LB-01 не имеют публичных IP. Для подключения используйте SSH jump-host:
>
> ```bash
> LB=111.88.241.156
> alias ssh-yc='ssh -o StrictHostKeyChecking=no -J ubuntu@$LB'
> ```
>
> Пример: `ssh-yc ubuntu@10.0.3.10 "command"`


## 1. 🚨 Выход сервера из строя

### 1.1. Сбой балансировщика (LB-01)

| Параметр | Описание |
|----------|----------|
| **Симптомы** | Недоступен веб-интерфейс MediaWiki, не работают SSH-подключения через jump-host |
| **Время восстановления** | 5-10 минут |

**Действия:**

```bash
# 1. Проверить статус ВМ в Yandex Cloud Console
yc compute instance get lb-01

# 2. Если ВМ остановлена — запустить
yc compute instance start lb-01

# 3. Если ВМ не запускается — пересоздать через Terraform
cd /path/to/diploma-project/terraform
terraform apply -target=yandex_compute_instance.lb-01
```

---

### 1.2. Сбой сервера приложения (APP-01 или APP-02)

| Параметр | Описание |
|----------|----------|
| **Симптомы** | Один из серверов не отвечает, часть запросов возвращается с ошибкой 502 |
| **Время восстановления** | 5-10 минут |

> ⚠️ **При сбое одного APP-сервера трафик автоматически идёт на второй.**

**Действия:**

```bash
# 1. Проверить статус ВМ
yc compute instance get app-01  # или app-02

# 2. Если ВМ остановлена — запустить
yc compute instance start app-01

# 3. Если ВМ не запускается — пересоздать
terraform apply -target=yandex_compute_instance.app-01

# 4. После восстановления — синхронизировать конфигурацию
cd /path/to/diploma-project/ansible
ansible-playbook site.yml --tags mediawiki --limit app-01
```

---

### 1.3. Сбой сервера БД (DB-01 или DB-02)

| Параметр | Описание |
|----------|----------|
| **Симптомы** | Ошибки подключения к базе данных, MediaWiki показывает ошибку |
| **Время восстановления** | 10-20 минут |

---

#### При сбое DB-01 (Master)

> **IP-адреса:**
> - LB-01 (jump-host): `111.88.241.156`
> - DB-01 (Master, сбой): `10.0.3.10`
> - DB-02 (Replica): `10.0.3.11`
> - APP-01: `10.0.2.10`
> - APP-02: `10.0.2.11`

**Шаг 1. Подключиться к DB-02 через jump-host:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.11
```

**Шаг 2. На DB-02 проверить статус реплики:**

```bash
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `t` (true) — реплика жива и готова к повышению.

**Шаг 3. На DB-02 повысить реплику до мастера:**

```bash
sudo -u postgres psql -c "SELECT pg_promote();"
```

Ожидаемый результат: `t` (true) — повышение запущено.

**Шаг 4. На DB-02 убедиться, что теперь это мастер:**

```bash
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `f` (false) — сервер больше не реплика, а мастер.

**Шаг 5. Выйти с DB-02:**

```bash
exit
```

**Шаг 6. Подключиться к APP-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.10
```

**Шаг 7. На APP-01 изменить IP базы данных в конфиге MediaWiki:**

```bash
sudo nano /var/www/mediawiki/LocalSettings.php
```

Найти строку:

```php
$wgDBserver = "10.0.3.10";
```

Заменить на:

```php
$wgDBserver = "10.0.3.11";
```

Сохранить и выйти.

**Шаг 8. На APP-01 перезапустить PHP-FPM:**

```bash
sudo systemctl reload php8.1-fpm
```

**Шаг 9. Выйти с APP-01:**

```bash
exit
```

**Шаг 10. Подключиться к APP-02:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.11
```

**Шаг 11. На APP-02 повторить шаги 7-8** (изменить `$wgDBserver` на `10.0.3.11` и перезапустить PHP-FPM).

**Шаг 12. Выйти с APP-02:**

```bash
exit
```

**Шаг 13. Проверить работоспособность MediaWiki:**

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://111.88.241.156
```

Ожидаемый результат: `200`.

---

#### Для восстановления DB-01 как реплики

> После того как DB-02 стал новым мастером, DB-01 нужно пересоздать как реплику.
>
> **IP-адреса:**
> - DB-02 (новый Master): `10.0.3.11`
> - DB-01 (восстанавливается): `10.0.3.10`

**Шаг 1. Запустить DB-01, если он выключен:**

```bash
yc compute instance start db-01
```

**Шаг 2. Подключиться к DB-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.10
```

**Шаг 3. На DB-01 остановить PostgreSQL:**

```bash
sudo systemctl stop postgresql
```

**Шаг 4. На DB-01 удалить старые данные:**

```bash
sudo rm -rf /var/lib/postgresql/14/main
sudo mkdir -p /var/lib/postgresql/14/main
sudo chown postgres:postgres /var/lib/postgresql/14/main
```

**Шаг 5. На DB-01 сделать копию с нового мастера (DB-02):**

```bash
sudo -u postgres bash -c "PGPASSWORD='ReplPass2024!' pg_basebackup -h 10.0.3.11 -U replicator -D /var/lib/postgresql/14/main -P -R"
```

Флаг `-R` автоматически создаст файл `standby.signal` и настроит подключение к мастеру.

> ⚠️ **Важно:** Если `pg_basebackup` завершён успешно, но PostgreSQL не запускается — проверьте логи:
>
> ```bash
> sudo tail -30 /var/log/postgresql/postgresql-14-main.log
> ```
>
> **Частая ошибка:** `max_wal_senders = 3 is a lower setting than on the primary server, where its value was 10`
>
> **Решение:** Увеличить `max_wal_senders` на реплике до значения ≥ мастера:
>
> ```bash
> sudo sed -i 's/max_wal_senders = 3/max_wal_senders = 10/' /etc/postgresql/14/main/postgresql.conf
> ```

**Шаг 6. На DB-01 исправить права на директорию данных:**

```bash
sudo chmod 0700 /var/lib/postgresql/14/main
```

**Шаг 7. На DB-01 запустить PostgreSQL:**

```bash
sudo systemctl start postgresql@14-main
```

> Если сервис не запустился — проверить статус:
>
> ```bash
> sudo systemctl status postgresql@14-main --no-pager
> ```

**Шаг 8. На DB-01 проверить, что сервер стал репликой:**

```bash
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `t` (true) — сервер работает как реплика.

**Шаг 9. Выйти с DB-01:**

```bash
exit
```

---

#### При сбое DB-02 (Replica)

> **IP-адреса:**
> - LB-01 (jump-host): `111.88.241.156`
> - DB-02 (Replica, сбой): `10.0.3.11`

**Шаг 1. Запустить DB-02, если он выключен:**

```bash
yc compute instance start db-02
```

**Шаг 2. Подключиться к DB-02:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.11
```

**Шаг 3. На DB-02 перенастроить репликацию через Ansible:**

```bash
cd /home/leff/diploma-project/ansible
ansible-playbook site.yml --tags postgresql --limit db-02
```

**Шаг 4. На DB-02 проверить статус реплики:**

```bash
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `t` (true) — реплика работает.

**Шаг 5. Выйти с DB-02:**

```bash
exit
```

---


## 3. 💾 Восстановление из резервной копии

### 3.1. Восстановление файловой системы MediaWiki

> **IP-адреса:**
> - LB-01 (jump-host): `111.88.241.156`
> - APP-01: `10.0.2.10`
> - APP-02: `10.0.2.11`
> - BACKUP-01: `10.0.5.10`

**Шаг 1. Подключиться к BACKUP-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.5.10
```

**Шаг 2. На BACKUP-01 найти последний бэкап:**

```bash
ls -lt /backup/mediawiki/fs/
```

Записать имя последнего файла (например: `mediawiki_fs_20260410_030000.tar.gz`).

**Шаг 3. Выйти с BACKUP-01:**

```bash
exit
```

**Шаг 4. Подключиться к APP-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.10
```

**Шаг 5. На APP-01 остановить PHP-FPM:**

```bash
sudo systemctl stop php8.1-fpm
```

**Шаг 6. На APP-01 удалить текущие файлы MediaWiki:**

```bash
sudo rm -rf /var/www/mediawiki/*
```

**Шаг 7. На APP-01 восстановить файлы из бэкапа:**

```bash
sudo tar -xzf /backup/mediawiki/fs/mediawiki_fs_YYYYMMDD_HHMMSS.tar.gz -C /var/www/
```

Заменить `mediawiki_fs_YYYYMMDD_HHMMSS.tar.gz` на имя файла из шага 2.

**Шаг 8. На APP-01 проверить права:**

```bash
sudo chown -R www-data:www-data /var/www/mediawiki
sudo chmod -R 755 /var/www/mediawiki
```

**Шаг 9. На APP-01 запустить PHP-FPM:**

```bash
sudo systemctl start php8.1-fpm
```

**Шаг 10. Выйти с APP-01:**

```bash
exit
```

**Шаг 11. Повторить шаги 4-10 для APP-02** (подключаться к `10.0.2.11`).

---

### 3.2. Восстановление базы данных из бэкапа

> **IP-адреса:**
> - LB-01 (jump-host): `111.88.241.156`
> - DB-01 (Master): `10.0.3.10`
> - BACKUP-01: `10.0.5.10`

**Шаг 1. Подключиться к BACKUP-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.5.10
```

**Шаг 2. На BACKUP-01 найти последний бэкап БД:**

```bash
ls -lt /backup/mediawiki/db/
```

Записать имя последнего файла (например: `mediawiki_db_20260410_020000.sql.gz`).

**Шаг 3. Выйти с BACKUP-01:**

```bash
exit
```

**Шаг 4. Подключиться к DB-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.10
```

**Шаг 5. На DB-01 остановить PostgreSQL:**

```bash
sudo systemctl stop postgresql
```

**Шаг 6. На DB-01 удалить текущую базу данных:**

```bash
sudo -u postgres dropdb -f my_wiki
sudo -u postgres createdb -O wikiuser my_wiki
```

**Шаг 7. На DB-01 восстановить БД из бэкапа:**

```bash
gunzip -c /backup/mediawiki/db/mediawiki_db_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql my_wiki
```

Заменить `mediawiki_db_YYYYMMDD_HHMMSS.sql.gz` на имя файла из шага 2.

**Шаг 8. На DB-01 запустить PostgreSQL:**

```bash
sudo systemctl start postgresql
```

**Шаг 9. На DB-01 проверить восстановление:**

```bash
sudo -u postgres psql -d my_wiki -c "SELECT COUNT(*) FROM wiki_page;"
```

Ожидаемый результат: число строк больше 0.

**Шаг 10. Выйти с DB-01:**

```bash
exit
```

**Шаг 11. Перенастроить репликацию на DB-02 через Ansible:**

```bash
cd /home/leff/diploma-project/ansible
ansible-playbook site.yml --tags postgresql
```

---

## 4. ✅ Проверка работоспособности после восстановления

> **IP-адреса:**
> - LB-01 (jump-host): `111.88.241.156`
> - APP-01: `10.0.2.10`
> - DB-01: `10.0.3.10`

**Шаг 1. Проверить HTTP-доступность:**

```bash
curl -I http://111.88.241.156
```

Ожидаемый результат: `HTTP/1.1 301` или `HTTP/1.1 200`.

**Шаг 2. Проверить загрузку главной страницы MediaWiki:**

```bash
curl http://111.88.241.156/index.php?title=Main_Page
```

Ожидаемый результат: HTML-код страницы MediaWiki.

**Шаг 3. Подключиться к APP-01:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.10
```

**Шаг 4. На APP-01 проверить подключение к БД:**

```bash
sudo -u www-data php -r "new PDO('pgsql:host=10.0.3.10;dbname=my_wiki', 'wikiuser', 'password');"
```

Ожидаемый результат: никаких ошибок.

**Шаг 5. Выйти с APP-01:**

```bash
exit
```

**Шаг 6. Проверить доступность Zabbix:**

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://111.88.241.156/zabbix/
```

Ожидаемый результат: `200`.

**Шаг 7. Подключиться к APP-01 и проверить Nginx:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.10
sudo systemctl status nginx
```

Ожидаемый результат: `active (running)`.

**Шаг 8. Выйти с APP-01:**

```bash
exit
```

**Шаг 9. Подключиться к DB-01 и проверить PostgreSQL:**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.10
sudo systemctl status postgresql
```

Ожидаемый результат: `active (running)`.

**Шаг 10. Выйти с DB-01:**

```bash
exit
```

---

## 5. 📞 Контакты

| Роль | Контакт |
|------|---------|
| 👤 Основной администратор | `technik906-afk` |
| 👨‍💼 Техлид | `Майк` |

---

## Приложение: Команды для быстрой диагностики

### Проверка статуса всех ВМ

```bash
yc compute instance list
```

### Проверка доступности всех хостов через Ansible

```bash
cd /home/leff/diploma-project/ansible
ansible all -m ping
```

### Проверка Nginx на LB и APP

```bash
cd /home/leff/diploma-project/ansible
ansible lb,app -m systemd -a "name=nginx"
```

### Проверка PostgreSQL на DB

```bash
cd /home/leff/diploma-project/ansible
ansible db -m systemd -a "name=postgresql"
```

### Проверка Zabbix

```bash
cd /home/leff/diploma-project/ansible
ansible zabbix -m systemd -a "name=zabbix-server"
```

### Просмотр логов Nginx на APP-01

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.2.10
sudo journalctl -u nginx -f
```

### Просмотр логов PostgreSQL на DB-01

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.10
sudo journalctl -u postgresql -f
```

### Проверка репликации PostgreSQL

**Проверка DB-01 (должен быть мастером):**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.10
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `f` (false — это мастер).

**Проверка DB-02 (должен быть репликой):**

```bash
ssh -J ubuntu@111.88.241.156 ubuntu@10.0.3.11
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

Ожидаемый результат: `t` (true — это реплика).
