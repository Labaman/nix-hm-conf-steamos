# Nix Home Manager Config for SteamOS

[English](README.md) | **Русский**

Nix — один из официально поддерживаемых способов установки дополнительного ПО на SteamOS (поддержка появилась в версии 3.5). Пакеты и настройки Nix не слетают при обновлениях SteamOS — достойная альтернатива Flatpak, Distrobox и Homebrew.

Этот репозиторий содержит минимальный базовый конфиг [Home Manager](https://github.com/nix-community/home-manager) для SteamOS. Конфиг учитывает особенности работы Nix на SteamOS и включает фиксы ключевых проблем, которые могут нарушить работу системы и сторонних приложений, установленных не через Nix.

## Возможности

| Фикс / Фича | Описание |
|-------------|----------|
| Порядок XDG_DATA_DIRS | Сохраняется исходный порядок путей в `XDG_DATA_DIRS` (Flatpak первым). Без этого Flatpak-приложения могут не отображаться в меню или не открываться: вместо них запускаются системные заглушки из read-only раздела SteamOS (например, «Install Firefox») (HM [#8076](https://github.com/nix-community/home-manager/issues/8076) / [#9356](https://github.com/nix-community/home-manager/pull/9356)) |
| Обновление меню KDE | Иконки Nix-приложений появляются в лаунчере сразу после `switch`, без перезахода в сессию (при первом switch иконки могут быть пустыми, но приложения запускаются). Также предотвращает исчезновение системных приложений из меню. |
| GPU для Nix GUI-приложений | `targets.genericLinux.gpu`: драйверы mesa (OpenGL + Vulkan/RADV) через `/run/opengl-driver`, без обёрток на приложения; `nix-gpu-setup` сохраняет настройку при обновлениях SteamOS |
| Нативный Wayland для Nix-GUI-приложений | `NIXOS_OZONE_WL` для Electron/Chromium-приложений (Qt выбирает Wayland сам) |
| Закреплённый `nixpkgs` | `nix shell nixpkgs#…` и `nix-shell -p` используют тот же nixpkgs, что и конфиг |
| EmuDeck / rustup | Изменяемый `~/.gitconfig` рядом с управляемым HM git-конфигом |
| Строка приглашения оболочки (Starship) | Единый вид приглашения оболочки для bash, zsh и fish в стиле дефолтного SteamOS: `(user@host dir) [ветка*]$` |

## Использование

Установите Nix, если он ещё не установлен. Рекомендуется официальный установщик [NixOS/nix-installer](https://github.com/NixOS/nix-installer): он сам определяет SteamOS и выполняет начальную настройку:

```bash
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

Затем:

```bash
git clone https://github.com/Labaman/nix-hm-conf-steamos ~/.config/home-manager
nix run home-manager/master -- switch
```

При первой активации Home Manager запускается прямо из своего флейка через `nix run`, поэтому отдельно устанавливать его не нужно. После успешной активации команда `home-manager` появится в вашем профиле, и дальше для применения любых изменений конфига достаточно `home-manager switch`.

Если файл, которым должен управлять Home Manager, уже существует (например, `~/.bashrc` при включении bash), он переименовывается в `<файл>.hm-backup` вместо ошибки. Если такая копия уже есть, `switch` остановится: удалите или переименуйте старую копию и запустите его снова.

Затем откройте новое окно терминала: текущее запущено до `switch`, поэтому в его `PATH` ещё нет `~/.local/bin`, куда установлен `nix-gpu-setup`.

Настроить GPU-драйверы для Nix GUI-приложений (спросит пароль sudo; перезапускать, когда `switch` предупреждает, что драйверы требуют обновления):

```bash
nix-gpu-setup
```

Свои пакеты и программы добавляйте в `home.nix` под комментарием `# Add your own packages here`.

## Обновление и обслуживание

**Обновление программ.** Все пакеты берутся из источников флейка (`inputs`: nixpkgs и Home Manager), зафиксированных в `flake.lock`. Чтобы обновить программы, обновите эти источники и примените конфиг заново:

```bash
cd ~/.config/home-manager
nix flake update      # обновить nixpkgs и home-manager до последнего коммита
home-manager switch   # пересобрать и активировать обновлённые программы
```

Посмотреть поколения (для отката — активировать предыдущее):

```bash
home-manager generations
```

Освободить место. Старые поколения хранятся, пока вы их не удалите, а каждый `switch` добавляет новое:

```bash
home-manager expire-generations "-7 days"   # удалить поколения Home Manager старше 7 дней
nix-collect-garbage --delete-older-than 7d   # удалить старые поколения профиля и неиспользуемые пути в store
nix store optimise                           # дедупликация store через хардлинки
```

Удалить сразу все старые поколения, оставив только текущее, — `nix-collect-garbage -d`.

### Удаление

Сначала удалите Home Manager: управляемые им файлы в домашнем каталоге — это симлинки в Nix store, и без этого шага они останутся битыми:

```bash
home-manager uninstall
```

Затем удалите сам Nix с помощью nix-installer — см. [NixOS/nix-installer → Uninstalling](https://github.com/NixOS/nix-installer#uninstalling):

```bash
/nix/nix-installer uninstall
```

`nix-gpu-setup` оставил два файла в `/etc` — удалите и их:

```bash
sudo rm /etc/tmpfiles.d/non-nixos-gpu.conf /etc/atomic-update.conf.d/non-nixos-gpu.conf
```

Если вы сменили логин-шелл на zsh или fish, он продолжит работать — это системные бинарники.

## Оболочка

Home Manager записывает переменные сессии (в том числе `~/.local/bin` в `PATH`) в `hm-session-vars.sh`, а подключает его только оболочка под управлением Home Manager. Оболочка входа в SteamOS — bash, поэтому `programs.bash` в `home.nix` включён по умолчанию: после первого `switch` откройте новое окно терминала. Существующие `~/.bashrc` и `~/.bash_profile` переименовываются в `*.hm-backup`; свои настройки из них перенесите в опции `programs.bash` или в заготовку для своих строк в `programs.bash.initExtra`.

| Оболочка | Покрытие переменных сессии | Примечания |
|----------|---------------------------|------------|
| **bash** | login + интерактивные шеллы | Дефолт SteamOS; не требует смены оболочки. Две строки `# bash only` в `home.nix` закрывают то, что bash сам упускает: дубли в `XDG_DATA_DIRS` из `.bashrc` и `NIXOS_OZONE_WL` для приложений из меню KDE. |
| **zsh** | login, интерактивный и non-interactive | Переменные сессии загружаются в любом zsh: при входе — через `.zprofile`, в остальных случаях — через `.zshenv`. Не трогает bash-дотфайлы. |
| **fish** | login, интерактивный и non-interactive | Автодополнение, подсказки команд и подсветка синтаксиса работают из коробки без доп. настройки. Не трогает bash-дотфайлы. Важно: fish не совместим с POSIX/bash — bash-скрипты не запустятся напрямую внутри fish. |

### zsh или fish вместо bash (по желанию)

bash работает из коробки, так что смена оболочки — дело вкуса: фиксы в `home.nix` одинаково работают в любой оболочке, а две строки только для bash ничего не делают, когда bash выключен.

1. Раскомментируйте блок своей оболочки в `home.nix` и запустите `home-manager switch`.
2. Смените оболочку входа. Указывайте **системный** бинарник, а не установленный через Nix: тогда вход в систему продолжит работать, даже если удалить Nix (оба шелла идут в комплекте с SteamOS).

   Для **zsh**:

   ```bash
   chsh -s /bin/zsh
   ```

   Для **fish**:

   ```bash
   chsh -s /bin/fish
   ```

3. Перезайдите в сессию: SteamOS запускает графическую сессию и новые окна Konsole с вашей оболочкой входа.

Блок bash можно оставить включённым для bash-сессий или закомментировать.
