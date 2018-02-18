PROMPT_SUMMARY_STATS='\[\033[1;37m\]---=[ \
\[\033[1;36m\]ret: \
\[\033[1;${PROMPT_SUMMARY_EXIT_CODE_COLOR}m\]$PROMPT_SUMMARY_EXIT_CODE \
\[\033[1;37m\]| \
\[\033[1;36m\]user: \
\[\033[1;33m\]$PROMPT_SUMMARY_FORMATED_TIME_USER \
\[\033[1;36m\]sys: \
\[\033[1;33m\]$PROMPT_SUMMARY_FORMATED_TIME_SYS \
\[\033[1;37m\]| \
\[\033[1;36m\]pid: \
\[\033[1;33m\]$$ \
\[\033[1;37m\]| \
\[\033[1;36m\]tty: \
\[\033[1;33m\]${PROMPT_SUMMARY_VARS[11]} \
\[\033[1;37m\]| \
\[\033[1;36m\]hostname: \
\[\033[1;33m\]${PROMPT_SUMMARY_VARS[12]} \
\[\033[1;37m\]| \
\[\033[1;36m\]path: \
\[\033[1;33m\]${PROMPT_SUMMARY_VARS[1]} \
\[\033[1;37m\]]=\
$(get_fill_string)\n$(tput sgr0)'

PS1="${PROMPT_SUMMARY_STATS}"
