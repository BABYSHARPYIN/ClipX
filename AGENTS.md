# ClipX agent guide

ClipX is a menu-bar clipboard manager for macOS 14 and later. Bundle id: `com.clipx.app`. An agent that has only cloned this repo should use the command below and then stop when the script asks for a person.

This file is English first, then 中文. `README.md` and `README_EN.md` point here.

## One command

From the repository root, on a Mac that is logged in to the desktop:

```bash
bash scripts/install.sh
```

That script is safe to run again. It will:

1. Refuse anything that is not macOS 14 or newer, or that does not have Swift 5.9 or newer (Xcode 15 or the matching command line tools).
2. Stop a ClipX that is already running.
3. Build with `scripts/build_app.sh --no-dmg` (the default `scripts/build_app.sh` still builds `build/ClipX.dmg` and reveals it in Finder).
4. Copy the app to `/Applications/ClipX.app` unless you pass `--keep-in-build`.
5. Clear the quarantine attribute and ad-hoc sign the copy. Signing failure stops the script.
6. Launch ClipX and confirm the process stays up.
7. Ask that signed binary whether Accessibility is trusted.

Useful variants:

```bash
bash scripts/install.sh --prefix "$HOME/Applications"
bash scripts/install.sh --keep-in-build
bash scripts/install.sh --check
```

`--check` does not rebuild or re-sign. Use it after a person approves Accessibility.

## Exit codes

| Code | Meaning | What the agent should do |
|------|---------|--------------------------|
| 0 | `result: ready`. ClipX is running and Accessibility is trusted. | Stop. The app is usable. |
| 2 | `result: needs_human`. ClipX is running, Accessibility is not trusted. | Stop. Ask a person to allow ClipX, then run the `next:` command from the script output. That command is `--check`. |
| 1 | `result: failed` on stderr, with `error:`. | Read the error. Do not keep retrying a full install if the error is the operating system or a missing toolchain. |

Stdout from a finished run includes machine-readable lines: `result`, `accessibility` (`trusted` or `not_trusted`), `app`, `bundle_id`, `running`, and `pid`. Exit 2 also prints `next:`.

## The only permission, and the human click

ClipX needs **Accessibility**, and only for the global hotkey (`Cmd+Shift+V` unless the user changed it). The menu-bar icon opens the panel without that permission. Clipboard history, OCR, on-device translation, and speech do not add another privacy prompt. Login at startup is an optional switch inside the app, not part of install.

On launch, if Accessibility is missing, the app calls the system prompt (`AXIsProcessTrustedWithOptions`). The install script also opens **System Settings → Privacy & Security → Accessibility**.

A person has to turn ClipX on. This script cannot do that click. It does not write the privacy database and it does not turn off System Integrity Protection. If ClipX is not in the list, click **+** and choose the `app:` path the script printed.

Approving while ClipX is already running does not bind the hotkey. `RegisterEventHotKey` runs at launch. `--check` relaunches the same signed copy so the hotkey can register. Run:

```bash
bash scripts/install.sh --check
```

Trust follows the ad-hoc signature and the path. A later full `bash scripts/install.sh` signs a new build, and macOS asks again. `build/ClipX.app` and `/Applications/ClipX.app` are different grants. After the person clicks Allow, do not rebuild unless the source changed.

## How to tell it is running

- The script prints `running: yes` and a pid, or exits 1.
- `pgrep -x ClipX` shows that pid.
- A clipboard icon sits in the menu bar. ClipX does not appear in the Dock.
- After `accessibility: trusted`, `Cmd+Shift+V` should toggle the panel.

On launch the app writes `trusted` or `not_trusted` to `~/Library/Application Support/ClipboardHistory/accessibility-status`. The install script removes that file, starts ClipX, and waits for a new one, so the result belongs to the process that is staying open. `ClipX --accessibility-status` prints the same word and exits 0 or 2 without staying running. Prefer `scripts/install.sh` so the relaunch and the System Settings hand-off stay in one place.

## Build without installing

```bash
bash scripts/build_app.sh
open build/ClipX.app
```

That still creates `build/ClipX.dmg`. Opening `ClipboardHistory.xcodeproj` also builds, but that project’s product name and bundle id are not `ClipX` / `com.clipx.app`. Agents should install only through `scripts/install.sh`.

`bash scripts/test_install.sh` checks argument handling and version checks. It does not compile the app. A Linux machine can run that test and cannot install ClipX.

## Common failures

| What you see | What to do |
|--------------|------------|
| `can only be installed on macOS` | Use a Mac. This repository cannot be launched on Linux. |
| Swift is missing or older than 5.9 | Install Xcode 15 or newer and run `xcode-select --install` if needed. |
| `Cannot write to /Applications` | `bash scripts/install.sh --prefix "$HOME/Applications"` after creating that folder. Do not wrap the script with administrator rights. |
| Exit 2, `accessibility: not_trusted` | A person allows ClipX in Accessibility, then you run the printed `next:` command. Do not start a full install to “fix” exit 2. |
| Hotkey still dead after they clicked Allow | Run `bash scripts/install.sh --check` so ClipX relaunches with trust. |
| They allowed it, then a full install asked again | Expected. The new signature is a new app. Allow that copy, then use `--check` only. |
| Timeout waiting for `accessibility-status` | The Mac user has to be logged in to the GUI. SSH without a desktop session cannot finish this. The file is `~/Library/Application Support/ClipboardHistory/accessibility-status`. |
| Quarantine / “app is damaged” | The install script runs `xattr` and signs the app. For a release DMG installed by hand, the README still uses `xattr -cr /Applications/ClipX.app`. |
| Wrong bundle id | Install the `com.clipx.app` built by this script, not the Xcode product. |

## 中文

ClipX 是 macOS 14 及以上的菜单栏剪切板工具，bundle id 为 `com.clipx.app`。只克隆了仓库的代理，在已登录桌面的 Mac 上执行：

```bash
bash scripts/install.sh
```

脚本会检查系统与 Swift 5.9+，调用 `scripts/build_app.sh --no-dmg` 编译，默认安装到 `/Applications/ClipX.app`，去掉隔离属性，做 ad-hoc 签名，然后启动。直接运行 `scripts/build_app.sh` 仍会生成 DMG 并在 Finder 中显示，这条路径没有改掉。

退出码：

- **0**：`result: ready`，应用在运行且辅助功能已授权。
- **2**：`result: needs_human`，应用在运行，但辅助功能未授权。代理应停下来请人授权，然后只执行输出里的 `next:`（即 `--check`）。不要为了“修好”退出码 2 再完整安装一遍。
- **1**：失败。看 stderr 的 `error:`。

应用只需要**辅助功能**，用来注册全局热键（默认 `Cmd+Shift+V`）。菜单栏图标不依赖这项权限。剪切板记录、OCR、系统翻译和朗读不会再弹出别的隐私授权。登录时启动是应用里的可选项，不属于安装步骤。

在开启系统完整性保护的 Mac 上，脚本不能替用户授予辅助功能，也不会去改隐私数据库。首次启动时应用会弹出系统授权框，脚本会打开「系统设置 → 隐私与安全性 → 辅助功能」。若列表里没有 ClipX，点 **+** 选脚本打印的 `app:` 路径。

用户点允许时应用已经在运行的话，热键要等下次启动才会注册。所以授权后执行：

```bash
bash scripts/install.sh --check
```

`--check` 不重新编译、不重新签名，只会复查并重新启动同一份应用。再跑一遍不带 `--check` 的安装会换掉签名，系统会再问一次。`build/ClipX.app` 和 `/Applications/ClipX.app` 也是两次不同的授权。

确认方式：脚本输出 `running: yes` 和 pid，菜单栏出现剪切板图标（不进 Dock）。应用启动后会把 `trusted` 或 `not_trusted` 写到 `~/Library/Application Support/ClipboardHistory/accessibility-status`，安装脚本会删掉旧文件再等新的结果。`bash scripts/test_install.sh` 只检查脚本约定，不能在 Linux 上把应用装起来。Xcode 工程的产品名和 bundle id 与 `com.clipx.app` 不一致，代理安装请只用 `scripts/install.sh`。
