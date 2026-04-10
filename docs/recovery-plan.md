# План восстановления инфраструктуры MediaWiki

> 🔑 **Важно:** Все серверы кроме LB-01 не имеют публичных IP. Для подключения используйте SSH jump-host:
>
> ```bash
> LB=111.88.246.67
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

#### При сбое DB-01 (Master)

```bash
LB=111.88.246.67

# 1. Проверить статус реплики (DB-02)
ssh -J ubuntu@$LB ubuntu@10.0.3.11 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"

# 2. Если реплика работает — переключить приложение на неё
#    Изменить LocalSettings.php: $wgDBserver = "10.0.3.11"

# 3. Запустить DB-02 как master
ssh -J ubuntu@$LB ubuntu@10.0.3.11 "sudo -u postgres psql -c 'SELECT pg_promote();'"

# 4. Восстановить DB-01 из бэкапа или пересоздать
yc compute instance start db-01
# или
terraform apply -target=yandex_compute_instance.db-01
```

#### При сбое DB-02 (Replica)

```bash
# 1. Пересоздать реплику
yc compute instance start db-02

# 2. Настроить репликацию заново
ansible-playbook site.yml --tags postgresql --limit db-02
```

---

## 2. 🔄 Переключение на реплику БД

### Пошаговая инструкция

```bash
LB=111.88.246.67
DB_REPLICA=10.0.3.11
APP1=10.0.2.10
APP2=10.0.2.11
```

1. **Проверка статуса реплики**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB_REPLICA "sudo -u postgres psql -c 'SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();'"
   ```

2. **Остановка репликации**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB_REPLICA "sudo -u postgres psql -c 'SELECT pg_wal_replay_pause();'"
   ```

3. **Повышение до master**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB_REPLICA "sudo -u postgres psql -c 'SELECT pg_promote();'"
   ```

4. **Проверка что стала master** (должно вернуть `f`)
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB_REPLICA "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
   ```

5. **Обновление конфига APP-01**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP1 "sudo sed -i 's/10.0.3.10/10.0.3.11/g' /var/www/mediawiki/LocalSettings.php"
   ```

6. **Обновление конфига APP-02**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP2 "sudo sed -i 's/10.0.3.10/10.0.3.11/g' /var/www/mediawiki/LocalSettings.php"
   ```

7. **Перезапуск PHP-FPM**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP1 "sudo systemctl restart php8.1-fpm"
   ```

---

## 3. 💾 Восстановление из резервной копии

### 3.1. Восстановление файловой системы MediaWiki

```bash
LB=111.88.246.67
APP=10.0.2.10
BACKUP=10.0.5.10
```

1. **Найти последний бэкап**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$BACKUP "ls -lt /backup/mediawiki/fs/ | head -5"
   ```

2. **Очистить текущую директорию**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP "sudo rm -rf /var/www/mediawiki/*"
   ```

3. **Восстановить из бэкапа**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP "sudo tar -xzf /backup/mediawiki/fs/mediawiki_fs_YYYYMMDD_HHMMSS.tar.gz -C /var/www/"
   ```

4. **Проверить права**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$APP "sudo chown -R www-data:www-data /var/www/mediawiki && sudo chmod -R 755 /var/www/mediawiki"
   ```

5. **Повторить для APP-02** — повторить шаги 2-4 для `10.0.2.11`

---

### 3.2. Восстановление базы данных из бэкапа

```bash
LB=111.88.246.67
DB=10.0.3.10
BACKUP=10.0.5.10
```

1. **Найти последний бэкап**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$BACKUP "ls -lt /backup/mediawiki/db/ | head -5"
   ```

2. **Остановить PostgreSQL**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB "sudo systemctl stop postgresql"
   ```

3. **Восстановить БД**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB "gunzip -c /backup/mediawiki/db/mediawiki_db_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql my_wiki"
   ```

4. **Запустить PostgreSQL**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB "sudo systemctl start postgresql"
   ```

5. **Проверить подключение**
   ```bash
   ssh -J ubuntu@$LB ubuntu@$DB "sudo -u postgres psql -d my_wiki -c 'SELECT COUNT(*) FROM wiki_page;'"
   ```

6. **Перенастроить репликацию**
   ```bash
   ansible-playbook site.yml --tags postgresql
   ```

---

## 4. ✅ Проверка работоспособности после восстановления

```bash
LB=111.88.246.67
```

| № | Проверка | Ожидаемый результат |
|---|----------|---------------------|
| 1 | HTTP доступность | HTTP/1.1 301 или 200 |
| 2 | MediaWiki | HTML-страница MediaWiki |
| 3 | Подключение к БД | Без ошибок |
| 4 | Zabbix | HTTP 200 |
| 5 | Сервисы (Nginx) | ok на LB + APP |
| 6 | Сервисы (PostgreSQL) | ok на DB-01 + DB-02 |

**Команды для проверки:**

```bash
# 1. HTTP доступность
curl -I http://$LB

# 2. MediaWiki
curl http://$LB/index.php?title=Main_Page

# 3. Подключение к БД
ssh -J ubuntu@$LB ubuntu@10.0.2.10 "php -r \"new PDO('pgsql:host=10.0.3.10;dbname=my_wiki', 'wikiuser', 'password');\""

# 4. Zabbix
curl -o /dev/null -w "%{http_code}" http://$LB/zabbix/

# 5. Сервисы (Nginx)
ansible all -m systemd -a "name=nginx state=started"

# 6. Сервисы (PostgreSQL)
ansible db -m systemd -a "name=postgresql state=started"
```

---

## 5. 📞 Контакты

| Роль | Контакт |
|------|---------|
| 👤 Основной администратор | `technik906-afk` |
| 👨‍💼 Техлид | `Майк` |

---

## Приложение: Команды для быстрой диагностики

- **Проверка статуса всех ВМ**
  ```bash
  yc compute instance list --folder-id <folder-id>
  ```

- **Проверка доступности хостов**
  ```bash
  ansible all -m ping
  ```

- **Проверка Nginx**
  ```bash
  ansible lb,app -m systemd -a "name=nginx"
  ```

- **Проверка PostgreSQL**
  ```bash
  ansible db -m systemd -a "name=postgresql"
  ```

- **Проверка Zabbix**
  ```bash
  ansible zabbix -m systemd -a "name=zabbix-server"
  ```

- **Логи Nginx**
  ```bash
  ssh -J ubuntu@$LB ubuntu@10.0.2.10 "sudo journalctl -u nginx -f"
  ```

- **Логи PostgreSQL**
  ```bash
  ssh -J ubuntu@$LB ubuntu@10.0.3.10 "sudo journalctl -u postgresql -f"
  ```

- **Репликация PostgreSQL**
  ```bash
  # Master (должно вернуть f)
  ssh -J ubuntu@$LB ubuntu@10.0.3.10 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"

  # Replica (должно вернуть t)
  ssh -J ubuntu@$LB ubuntu@10.0.3.11 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
  ```
