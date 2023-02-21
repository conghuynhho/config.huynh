# Huynh Config.
This is my personal config for my terminal.
It also includes some useful bash scripts and git aliases.
Documentation is also included. 🤩

**Note: All the document here just for WINDOWS user**
## Installation
Clone this repo to your working directory.
```bash
git clone https://github.com/conghuynhho/config.huynh.git
```

Add environment variable of config directory to your system.
Replace `D:\Huynh\config.huynh\` with your config directory.
Run this command in your **windows command prompt**.:
```commandline
setx HUYNH_CONFIG_DIR "D:\Huynh\config.huynh\"
```

## Link git alias to config file
Run this command to add config
With bash:
```bash
git config --global include.path "$HUYNH_CONFIG_DIR\gitalias\gitalias.txt"
```
With cmd:
```commandline
git config --global include.path "%HUYNH_CONFIG_DIR%\gitalias\gitalias.txt"
```
With powershell:
```powershell
git config --global include.path "$env:HUYNH_CONFIG_DIR\gitalias\gitalias.txt"
```






