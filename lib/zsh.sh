precmd() { eval '$PROMPT_COMMAND' }

PROMPT_SUMMARY_STATS=$'\033[1;37m---=[ \033[1;36mret: \033[1;${PROMPT_SUMMARY_EXIT_CODE_COLOR}m$PROMPT_SUMMARY_EXIT_CODE \033[1;37m| \033[1;36muser: \033[1;33m$PROMPT_SUMMARY_FORMATED_TIME_USER \033[1;36msys: \033[1;33m$PROMPT_SUMMARY_FORMATED_TIME_SYS \033[1;37m| \033[1;36mpid: \033[1;33m$$ \033[1;37m| \033[1;36mtty: \033[1;33m${PROMPT_SUMMARY_VARS[11]} \033[1;37m| \033[1;36mshell: \033[1;33m${PROMPT_SUMMARY_VARS[14]} \033[1;37m| \033[1;36mhostname: \033[1;33m${PROMPT_SUMMARY_VARS[12]} \033[1;37m| \033[1;36mpath: \033[1;33m${PROMPT_SUMMARY_VARS[1]} \033[1;37m]=$(get_fill_string)\n$(tput sgr0)'

PROMPT="$PROMPT_SUMMARY_STATS"
