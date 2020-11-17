### Search query completions
This folder contains pre-cooked completion files for some shells.
To enable autocompletion for `rcli` source corresponding files.

#### Bash
To enable completions for `bash` shell:
1. Install completions package following ['Install bash-completion'](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-bash-completion) guide
2. Source the completion file:
```echo 'source <(rcli completion bash)' >>~/.bashrc```
3. Make the bash completion script available:
```cp ./completions/completions_bash /etc/bash_completion.d/rcli```
4. Restart the shell

#### PowerShell
To enable completions for `PowerShell`:
1. Make sure `PowerShell` profile file exists using command:
```Test-Path $profile```
2. (Skip, if profile exists) If profile file does not exist, create one:
```New-Item $profile -ItemType File -Force```
3. Open `$profile` file (`notepad $profile`, for example) and append content from `./completions/powershell.ps` to the end of the file.
4. Restart the shell