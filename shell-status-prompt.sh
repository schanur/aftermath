# declare -a OLD_TIMES
declare -a PROMPT_SUMMARY_LAST_TIME_USAGE
declare -a PROMPT_SUMMARY_TIME_DIFF

if   [ "$(echo $ZSH_VERSION)"  != "" ]; then
    SHELL_NAME="zsh"
elif [ "$(echo $BASH_VERSION)" != "" ]; then
    SHELL_NAME="bash"
else
    echo "shell-status-prompt.sh: No supported shell (Currently supported: bash and zsh)"
    return
fi

echo "Shell: ${SHELL_NAME}"

function to_lower {
    echo $1 |tr '[:upper:]' '[:lower:]'
}

function get_item_from_list {
    local FIELD_NO=${1}
    shift

    echo ${*} | sed -e 's/\ \+/\ /g' |cut -f ${FIELD_NO} -d ' '
}

function get_tty_for_pid () {
    get_item_from_list 7 "$(ps aux | grep ${1} | head -n 1)"
}

function init_prompt_summary {
    for I in $(seq 4); do
        PROMPT_SUMMARY_LAST_TIME_USAGE[${I}]=0
    done
    PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH=0
    PROMPT_SUMMARY_FILL_STRING=''
    PROMPT_SUMMARY_TTY=$(get_tty_for_pid $$)
    PROMPT_SUMMARY_STATIC_STRING_LENGTH=0
    local pid=${$}
    (( PROMPT_SUMMARY_STATIC_STRING_LENGTH=${#PROMPT_SUMMARY_TTY} + ${#pid} ))
}

function get_times_for_pid {
    local I=0
    local STAT=''
    builtin read STAT < /proc/$1/stat
    test ${SHELL_NAME} = "zsh" && setopt sh_word_split
    for STAT_OPT in $STAT; do
        (( I++ ))
        if [ $I -lt 14 ]; then
            continue
        fi
        if [ $I -gt 17 ]; then
            break
        fi
        builtin echo -ne "$STAT_OPT\n"
    done
    test ${SHELL_NAME} = "zsh" && unsetopt sh_word_split
}

function get_signal_name {
    local SIGNAL_NAME=$(builtin kill -l $1 2>/dev/null)
    if [ $? -ne 0 ]; then
        SIGNAL_NAME='unknown signal'
    fi
    builtin echo -n $SIGNAL_NAME
}

function calc_times_diff {
    local I=1
    local DIFF_LIST=''
    local DIFF
    local NEW_TIMES
    local TEMP_VAR

    NEW_TIMES=$(get_times_for_pid ${$})
    test ${SHELL_NAME} = "zsh" && setopt sh_word_split
    for TIME in $NEW_TIMES; do
        (( TEMP_VAR = TIME - PROMPT_SUMMARY_LAST_TIME_USAGE[I] ))
        PROMPT_SUMMARY_TIME_DIFF[${I}]=${TEMP_VAR}
        PROMPT_SUMMARY_LAST_TIME_USAGE[$I]=${TIME}
        (( I++ ))
    done
    test ${SHELL_NAME} = "zsh" && unsetopt sh_word_split
}

function format_time {
    local TIME=$1
    local LENGTH=${#TIME}
    while [ $LENGTH -lt 3 ]; do
        TIME="0$TIME"
        (( LENGTH++ ))
    done
    local TIME_MILLISECONDS=${TIME: -2}
    local TIME_SECONDS=${TIME:0:$LENGTH-2}
    local TIME_MINUTES=0
    (( TIME_MINUTES = TIME_SECONDS / 60 ))
    (( TIME_SECONDS = TIME_SECONDS % 60 ))
    builtin echo -n "${TIME_MINUTES}m${TIME_SECONDS}.${TIME_MILLISECONDS}s"
}

function color_per_exit_code {
    if [ $PROMPT_SUMMARY_EXIT_CODE -eq 0 ]; then
        PROMPT_SUMMARY_EXIT_CODE_COLOR='33'
    else
        PROMPT_SUMMARY_EXIT_CODE_COLOR='31'
    fi
}

function calc_variable_string_length {
    (( PROMPT_SUMMARY_STRING_LENGTH=
        ${#PROMPT_SUMMARY_EXIT_CODE}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_STATIC_STRING_LENGTH}
    ))
}

# TODO: reuse old fill string as long as screen size has not changed.
function get_fill_string {
    calc_variable_string_length
    local FILL_STRING_LENGTH=$COLUMNS
    (( FILL_STRING_LENGTH-=($PROMPT_SUMMARY_STRING_LENGTH+54) ))
    if [ $FILL_STRING_LENGTH -ne $PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH ]; then
        PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH=$FILL_STRING_LENGTH
        local FILL_STRING=""
        while [ $FILL_STRING_LENGTH -gt 15 ]; do
            (( FILL_STRING_LENGTH-=16 ))
            FILL_STRING=$FILL_STRING----------------
        done
        while [ $FILL_STRING_LENGTH -gt 0 ]; do
            (( FILL_STRING_LENGTH-- ))
            FILL_STRING=$FILL_STRING-
        done
        PROMPT_SUMMARY_FILL_STRING=$FILL_STRING
    fi
    builtin echo -n $PROMPT_SUMMARY_FILL_STRING
}

function pre_prompt {
    PROMPT_SUMMARY_EXIT_CODE=$(builtin echo $?)
    color_per_exit_code
    if [ $PROMPT_SUMMARY_EXIT_CODE -gt 128 ]; then
        if [ !$(to_lower "x_$PROMPT_SUMMARY_OPTION_SHOW_SIGNAL") = 'x_no' ]; then
            local SIGNAL_NO=$PROMPT_SUMMARY_EXIT_CODE
            (( SIGNAL_NO-=128 ))
            PROMPT_SUMMARY_EXIT_CODE="$PROMPT_SUMMARY_EXIT_CODE ($(get_signal_name $SIGNAL_NO))"
        fi
    fi

    calc_times_diff
    PROMPT_SUMMARY_FORMATED_TIME_USER=$(format_time ${PROMPT_SUMMARY_TIME_DIFF[3]})
    PROMPT_SUMMARY_FORMATED_TIME_SYS=$(format_time ${PROMPT_SUMMARY_TIME_DIFF[4]})
}

PROMPT_COMMAND=pre_prompt


case ${SHELL_NAME} in
    bash)
        CURRENT_PATH="$(dirname $BASH_SOURCE)"
        source "${CURRENT_PATH}/lib/bash.sh"
        ;;
    zsh)
        CURRENT_PATH="$(dirname $(readlink -e ${(%):-%x}))"
        source "${CURRENT_PATH}/lib/zsh.sh"
        ;;
esac

init_prompt_summary

PROMPT_SUMMARY_LOADED=yes
