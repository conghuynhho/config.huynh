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
git config --global include.path "$HUYNH_CONFIG_DIR/gitalias/gitalias.txt"
```
With cmd:
```commandline
git config --global include.path "%HUYNH_CONFIG_DIR%/gitalias/gitalias.txt"
```
With powershell:
```powershell
git config --global include.path "$env:HUYNH_CONFIG_DIR/gitalias/gitalias.txt"
```

## Link bash script to bashrc and bash_profile

Run this command in your **bash**:
```bash
echo -e '\ntest -f $HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc && . $HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc || echo "Warning: $HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc file not found."' >> ~/.bash_profile
```

Run this command in your **windows command prompt**:
```commandline
echo -e '\ntest -f %HUYNH_CONFIG_DIR%/terminal/bash-script/.mybashrc && . %HUYNH_CONFIG_DIR%/terminal/bash-script/.mybashrc || echo "Warning: $HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc file not found."' >> ~/.bash_profile
```

Run this command in your **windows powershell**:
```powershell
echo -e '\ntest -f $env:HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc && . $env:HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc || echo "Warning: $HUYNH_CONFIG_DIR/terminal/bash-script/.mybashrc file not found."' >> ~/.bash_profile
```

Note: if ~/.bash_profile not exist, create it. This case is not tested. Supplement document will be added later.

## Link vim config to vimrc
Will be added later.


## Config oh-my-posh
**Install oh-my-posh:**
```powershell
winget install JanDeDobbeleer.OhMyPosh -s winget
```
Official document: https://ohmyposh.dev/docs/installation/windows

**Install Nerd Font**

Download this font: 
https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/CascadiaCode.zip
More fonts at:
https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/CascadiaCode.zip

After install, configure your terminal/editor to use the installed font.
#### git bash
In the `.mybashrc` file is already config oh-my-posh.
Just make sure to check the environment variable $HUYNH_CONFIG_DIR is correct and `.mybashrc` is sourced in the `.bash_profile`.

**Install lsd**
icon with ls command.

```powershell
scoop install lsd
```

**Readline with .inputrc**
```powershell
notepad ~/.inputrc
```

Add content in the `.my-inputrc` to the file.


#### powershell
**1. Install powershell from store**:
https://www.microsoft.com/store/productId/9MZ1SNWT0N5D

After install, open powershell and run this command:
```powershell
notepad $PROFILE
```

<!-- highlight the text with content "Add this line to the file" -->
<mark>Add this line to the file</mark>

```powershell
# load file in $HUYNH_CONFIG_DIR/terminal/terminal-utils/Microsoft.PowerShell_profile.ps1
if (Test-Path $env:HUYNH_CONFIG_DIR) {
    $profilePath = Join-Path $env:HUYNH_CONFIG_DIR "terminal/terminal-utils/Microsoft.PowerShell_profile.ps1"
    if (Test-Path $profilePath) {
        . $profilePath
    }
}
```

**2. Add Ps-readline to powershell**
Install PsReadLine:
```powershell
Install-Module -Name PSReadLine -Repository PSGallery -Force
```

Follow the step above to link the `$PROFILE` to the `$HUYNH_CONFIG_DIR\terminal\terminal-utils\Microsoft.PowerShell_profile.ps1`.
And all done. Enjoy your terminal. 🤩

**3. Install z command**
Run this command to install z command:
```powershell
Install-Module z -AllowClobber
```


**4. Add terminal icon**

Run this command to install terminal icon:
```powershell
Install-Module -Name Terminal-Icons -Repository PSGallery
```

If you already linked your local `$PROFILE` to the `$HUYNH_CONFIG_DIR\terminal\terminal-utils\Microsoft.PowerShell_profile` and it is all done. Enjoy your terminal. 🤩

`Todo:` Add these cool stuff for bash.
`Todo:` explore the `Microsoft.PowerShell_profile`
