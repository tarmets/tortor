# TorrServer Docker (актуальный 2025–2026)

Рабочий, лёгкий и всегда обновляемый образ TorrServer на базе YouROK/TorrServer (MatriX.136+).

Особенности:
- Автоматически ставит и обновляет с https://api.github.com/repos/YouROK/TorrServer/releases
- ffprobe с ffbinaries.com (v6.1+)
- Поддержка amd64 / arm64 / armhf / i386
- HTTP-авторизация через accs.db
- Объём образа ≈ 65 МБ

### Быстрый старт
```bash
mkdir -p torrserver/config torrserver/torrents
cp ts.ini.example torrserver/config/ts.ini
cp accs.db.example torrserver/config/accs.db
# отредактируй пароли в accs.db и ts.ini

docker compose up -d
