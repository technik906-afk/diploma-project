# План восстановления инфраструктуры MediaWiki

## Назначение документа

Этот документ описывает действия по восстановлению инфраструктуры в случае сбоев.
Предназначен для использования во время отсутствия основного администратора.

---

## 1. Выход сервера из строя

### 1.1. Сбой балансировщика (LB-01)

**Симптомы:**
- Недоступен веб-интерфейс MediaWiki
- Не работают SSH-подключения через jump-host

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

**Время восстановления:** 5-10 минут

---

### 1.2. Сбой сервера приложения (APP-01 или APP-02)

**Симптомы:**
- Один из серверов не отвечает
- Часть запросов возвращается с ошибкой 502

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
ansible-playbook playbooks/mediawiki.yml --limit app-01
```

**Важно:** При сбое одного APP-сервера трафик автоматически идёт на второй.

**Время восстановления:** 5-10 минут

---

### 1.3. Сбой сервера БД (DB-01 или DB-02)

**Симптомы:**
- Ошибки подключения к базе данных
- MediaWiki показывает ошибку

**Действия при сбое DB-01 (Master):**

```bash
# 1. Проверить статус реплики (DB-02)
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_is_in_recovery();"

# 2. Если реплика работает — переключить приложение на неё
#    Изменить конфигурацию MediaWiki (LocalSettings.php):
#    $wgDBserver = "10.0.3.11";  # IP DB-02

# 3. Запустить DB-02 как master
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_promote();"

# 4. Восстановить DB-01 из бэкапа или пересоздать
yc compute instance start db-01
# или
terraform apply -target=yandex_compute_instance.db-01
```

**Действия при сбое DB-02 (Replica):**

```bash
# 1. Пересоздать реплику
yc compute instance start db-02

# 2. Настроить репликацию заново
ansible-playbook playbooks/pg-replication.yml --limit db-02
```

**Время восстановления:** 10-20 минут

---

## 2. Переключение на реплику БД

### Пошаговая инструкция

```bash
# Шаг 1: Проверить статус реплики
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();"

# Шаг 2: Остановить репликацию
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_wal_replay_pause();"

# Шаг 3: Продвинуть реплику в master
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_promote();"

# Шаг 4: Проверить, что реплика стала master
ssh yc-db-02 sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
# Должно вернуть: f (false)

# Шаг 5: Обновить конфигурацию MediaWiki
ssh yc-app-01 "sudo sed -i 's/10.0.3.10/10.0.3.11/g' /var/www/mediawiki/LocalSettings.php"
ssh yc-app-02 "sudo sed -i 's/10.0.3.10/10.0.3.11/g' /var/www/mediawiki/LocalSettings.php"

# Шаг 6: Перезагрузить PHP-FPM (если используется)
ssh yc-app-01 "sudo systemctl restart php8.1-fpm"
ssh yc-app-02 "sudo systemctl restart php8.1-fpm"
```

---

## 3. Восстановление из резервной копии

### 3.1. Восстановление файловой системы MediaWiki

```bash
# Шаг 1: Найти последний бэкап
ssh backup-01 "ls -lt /backup/mediawiki/fs/ | head -5"

# Шаг 2: Очистить текущую директорию MediaWiki
ssh yc-app-01 "sudo rm -rf /var/www/mediawiki/*"

# Шаг 3: Восстановить из бэкапа
ssh yc-app-01 "sudo tar -xzf /backup/mediawiki/fs/mediawiki_fs_YYYYMMDD_HHMMSS.tar.gz -C /var/www/"

# Шаг 4: Проверить права доступа
ssh yc-app-01 "sudo chown -R www-data:www-data /var/www/mediawiki"
ssh yc-app-01 "sudo chmod -R 755 /var/www/mediawiki"

# Шаг 5: Повторить для второго сервера
# (повторить шаги 2-4 для yc-app-02)
```

---

### 3.2. Восстановление базы данных из бэкапа

```bash
# Шаг 1: Найти последний бэкап
ssh backup-01 "ls -lt /backup/mediawiki/db/ | head -5"

# Шаг 2: Остановить PostgreSQL (на время восстановления)
ssh yc-db-01 "sudo systemctl stop postgresql"

# Шаг 3: Восстановить БД из бэкапа
ssh yc-db-01 "gunzip -c /backup/mediawiki/db/mediawiki_db_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql my_wiki"

# Шаг 4: Запустить PostgreSQL
ssh yc-db-01 "sudo systemctl start postgresql"

# Шаг 5: Проверить подключение
ssh yc-db-01 "sudo -u postgres psql -d my_wiki -c 'SELECT COUNT(*) FROM wiki_page;'"

# Шаг 6: Перенастроить репликацию
ansible-playbook playbooks/pg-replication.yml
```

---

## 4. Проверка работоспособности после восстановления

```bash
# 1. Проверить доступность HTTP
curl -I http://<LB_PUBLIC_IP>

# 2. Проверить MediaWiki
curl http://<LB_PUBLIC_IP>/index.php?title=Main_Page

# 3. Проверить подключение к БД
ssh yc-app-01 "php -r \"new PDO('pgsql:host=10.0.3.10;dbname=my_wiki', 'wikiuser', 'password');\""

# 4. Проверить Zabbix
curl http://<ZABBIX_IP>/zabbix/

# 5. Проверить статус всех сервисов
ansible all -m systemd -a "name=nginx state=started"
ansible all -m systemd -a "name=postgresql state=started"
```

---

## 5. Контакты

| Роль | Контакт |
|------|---------|
| Основной администратор | technik906-afk |
| Техлид | Майк |

---

## Приложение: Команды для быстрой диагностики

```bash
# Проверка статуса всех ВМ
yc compute instance list --folder-id <folder-id>

# Проверка доступности хостов
ansible all -m ping

# Проверка сервисов
ansible all -m systemd -a "name=nginx"
ansible all -m systemd -a "name=postgresql"

# Просмотр логов
ssh yc-app-01 "sudo journalctl -u nginx -f"
ssh yc-db-01 "sudo journalctl -u postgresql -f"
```
