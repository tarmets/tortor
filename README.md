# torrserver
## Docker образ TorrServer — стриминг торрентов в HTTP

[TorrServer](https://github.com/YouROK/TorrServer) — стриминг торрентов в HTTP.

### Требования
- Docker
- ~256 MB RAM, ~512 MB диска

### Быстрый старт
```bash
mkdir -p /torrserver/db
docker run --name torrserver -e TZ=Europe/Moscow -d --restart=unless-stopped --net=host \
  -v /torrserver/db:/TS/db ghcr.io/tarmets/tortor
```

Настройки — в `ts.ini` (положить в `/torrserver/db`).
Логин/пароль — в `accs.db`.

Подробнее: https://github.com/YouROK/TorrServer
