# Aftermath
Get a nice summary line after each command you run on your shell.


## Features
   * Runs under Zsh and Bash.
   * Show userspace and kernel time of all programs that you run.
   * Show current pid of shell and tty.
   * In case of failure/suspend/etc, give the signal name and the exit code.
   * No external dependencies.


## How it looks like
![Alt text](/screenshot/screenshot_1_crop.png?raw=true "")


## Installation
   * Clone this repository or download and entract the snapshot to a location readable to you:
     git clone https://github.com/schanur/aftermath.git
   * Add the following line to the end of your .bashrc or .zshrc file:
     source "/path/of/this/repo/aftermath.sh"

You are done. You see your new status line after you restart your shell session.


## Credits
   * Many thanks to Joe Block (@unixorn) for the suggested name "Aftermath" which is from now on the project name.


## Contribution
Features missing? Give me a hint or implement it yourself and create a pull request.
If you like it (or even if you don't), a short feedback would be nice.

Thanks!

Björn Griebenow
