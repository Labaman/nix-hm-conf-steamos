# Nix Home Manager Config for SteamOS

[English](README.md) | **Русский**

Nix — один из официально поддерживаемых способов установки дополнительного ПО на SteamOS (поддержка появилась в версии 3.5). Пакеты и настройки Nix не слетают при обновлениях SteamOS — достойная альтернатива Flatpak, Distrobox и Homebrew.

Этот репозиторий содержит минимальный базовый конфиг [Home Manager](https://github.com/nix-community/home-manager) для SteamOS. Конфиг учитывает особенности работы Nix на SteamOS и включает фиксы ключевых проблем, которые могут нарушить работу системы и сторонних приложений, установленных не через Nix.

## Возможности

| Фикс / Фича | Описание |
|-------------|----------|
| Порядок XDG_DATA_DIRS | Flatpak остаётся первым в меню KDE — без этого вместо Flatpak-приложений (Firefox и др.) открывается системный стаб «Install Firefox» (HM [#8076](https://github.com/nix-community/home-manager/issues/8076) / [#9356](https://github.com/nix-community/home-manager/pull/9356)) |
| Обновление меню KDE | Иконки Nix-приложений появляются в лаунчере сразу после `switch`, без перезахода в сессию (при первом switch иконки могут быть пустыми, но приложения запускаются). Также предотвращает исчезновение системных приложений из меню. |
| GPU для Nix GUI-приложений | `targets.genericLinux.gpu`: драйверы mesa (OpenGL + Vulkan/RADV) через `/run/opengl-driver`, без обёрток на приложения; `nix-gpu-setup` сохраняет настройку при обновлениях SteamOS |
| Нативный Wayland для Nix-GUI-приложений | `NIXOS_OZONE_WL` + `QT_QPA_PLATFORM` для Electron/Qt-приложений |
| EmuDeck / rustup | Изменяемый `~/.gitconfig` рядом с управляемым HM git-конфигом |
| Строка приглашения оболочки (Starship) | Единый вид для bash, zsh и fish в стиле дефолтного SteamOS: `(user@host dir) [ветка*]$` |

## Использование

Установить Nix, если ещё не установлен (Рекомендуется использовать официальный установщик [NixOS/nix-installer](https://github.com/NixOS/nix-installer) - он автоматически определяет SteamOS и производит необходитмые начальные настройки):

```bash
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

Затем:

```bash
git clone https://github.com/Labaman/nix-hm-conf-steamos ~/.config/home-manager
nix run home-manager/master -- switch
```

Первый запуск Home Manager необходимо производить через разовый запуск `nix run` — отдельно ставить его не нужно. После этого Home Manager будет устанолвлен в ваш профиль и команда `home-manager` будет доступна на постоянной основе. Дальше достаточно просто запускать `home-manager switch` при любых изменениях конфигурации.

Настроить GPU-драйверы для Nix GUI-приложений (спросит пароль sudo; перезапускать, когда `switch` предупреждает, что драйверы требуют обновления):

```bash
nix-gpu-setup
```

Свои пакеты и программы добавляйте внутри `home.nix` ниже соответствующего комментария.

## Обновление и обслуживание

**Обновление программ.** Все пакеты берутся из зафиксированных источников (`inputs`) (nixpkgs + Home Manager) в `flake.lock`, поэтому обновить приложения — значит актуализировать эти источники и применить новый конфиг:

```bash
cd ~/.config/home-manager
nix flake update      # поднять nixpkgs + home-manager до свежего коммита
home-manager switch   # пересобрать и активировать обновлённые программы
```

Посмотреть поколения (для отката — активировать предыдущее):

```bash
home-manager generations
```

Освободить место — старые поколения хранятся до удаления, а каждый `switch` добавляет новое:

```bash
home-manager expire-generations "-7 days"   # удалить поколения Home Manager старше 7 дней
nix-collect-garbage --delete-older-than 7d   # удалить старые поколения профиля + несвязанные пути store
nix store optimise                           # дедуп store через хардлинки
```

Отчистить всё неактуальное (оставив только текущее поколение) — `nix-collect-garbage -d`.

### Удаление

Сначала удали Home Manager — управляемые им файлы в домашнем каталоге являются симлинками в Nix store и иначе останутся битыми:

```bash
home-manager uninstall
```

Затем удали сам Nix деинсталлятором установщика — см. [NixOS/nix-installer → Uninstalling](https://github.com/NixOS/nix-installer#uninstalling):

```bash
/nix/nix-installer uninstall
```

`nix-gpu-setup` оставил два файла в `/etc` — удали и их:

```bash
sudo rm /etc/tmpfiles.d/non-nixos-gpu.conf /etc/atomic-update.conf.d/non-nixos-gpu.conf
```

Если ты сменил логин-шелл на zsh или fish, он продолжит работать — это системные бинарники.

## Оболочка

Управляемая оболочка нужна, чтобы переменные сессии попадали в графическую сессию. Раскомментируй один из блоков в `home.nix`.

| Оболочка | Покрытие переменных сессии | Примечания |
|----------|---------------------------|------------|
| **bash** | login + интерактивные шеллы | Дефолт SteamOS; проще всего начать. Две строки `# bash only` в `home.nix` закрывают брешь в non-interactive запусках. |
| **zsh** | login, интерактивный и non-interactive | `.zshenv` сорсится при каждом запуске zsh — переменные сессии загружаются всегда, без доп. костылей. Не трогает bash-дотфайлы. Строки `# bash only` можно удалить. |
| **fish** | login, интерактивный и non-interactive | Автодополнение, подсказки команд и подсветка синтаксиса работают из коробки без доп. настройки. Не трогает bash-дотфайлы. Строки `# bash only` можно удалить. Важно: fish не совместим с POSIX/bash — bash-скрипты не запустятся напрямую внутри fish. |

### Смена дефолтного логин-шелла (опционально)

Рекомендуется сменить дефолтный bash на zsh или fish — их модули HM развиваются активнее и отпадает необходимость в специфичных для bash костылях.
При смене оболочки следует указывать **системный** бинарь, а не Nix-managed — тогда логин останется рабочим даже если Nix будет удалён (оба шелла идут в комплекте с SteamOS):

Переключиться на **zsh**:
```bash
chsh -s /bin/zsh
```

Переключиться на **fish**:
```bash
chsh -s /bin/fish
```

Сделай это **до** запуска `home-manager switch` с включённым модулем оболочки. После перезахода в сессию раскомментируй соответствующий блок в `home.nix`.
