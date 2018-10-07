declare -a PROMPT_SUMMARY_LAST_TIME_USAGE
declare -a PROMPT_SUMMARY_TIME_DIFF

# 0  ???
# 1  working directory;
# 2  working directory string length

# 10 Static variable list length
# 11 TTY
# 12 Hostname
# 13 PID
# 14 Shell name

# 60 Last command exit code
# 60 Last command exit code color string

# 70 Time diff 1 (utime)  user mode + guest time
# 71 Time diff 2 (stime)  kernel mode
# 72 Time diff 3 (cutime) time waited for children in user mode + guest time + cguest time(time spent running a virtual CPU)
# 73 Time diff 4 (cstime) time waited for children in kernel mode

# 76 Last command formated sys time
# 77 Last command formated user time

# 80 Line separation string
# 81 Current formated aftermath line
declare -a PROMPT_SUMMARY_VARS


if   [ -n "${BASH_VERSION}" ]; then
    SHELL_NAME="bash"
elif [ -n "${ZSH_VERSION}"  ]; then
    SHELL_NAME="zsh"
else
    echo "aftermath.sh: No supported shell (Currently supported: bash and zsh)"
    return
fi


# TODO: reuse old fill string as long as screen size has not changed.
function get_fill_string {
    # Calculate variable string length.
    ((
        PROMPT_SUMMARY_STRING_LENGTH=
        ${#PROMPT_SUMMARY_EXIT_CODE}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${PROMPT_SUMMARY_VARS[10]}+
        ${#PROMPT_SUMMARY_VARS[1]}
    ))

    local FILL_STRING_LENGTH=$COLUMNS
    #  + ${PROMPT_SUMMARY_VARS[10]}
    (( FILL_STRING_LENGTH -= ($PROMPT_SUMMARY_STRING_LENGTH + 83) ))
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


# Calculate all variables which are later used by PROMPT_COMMAND.
function pre_prompt {
    PROMPT_SUMMARY_EXIT_CODE=$(builtin echo $?)

    # Set global PROMPT_SUMMARY_EXIT_CODE_COLOR variable to a shell escape
    # color index. If the last command succeeded use a normal unobtrusive
    # color. On error us a color like red.
    # TODO: Make colora config variables
    if [ $PROMPT_SUMMARY_EXIT_CODE -eq 0 ]; then
        PROMPT_SUMMARY_EXIT_CODE_COLOR='33'
    else
        PROMPT_SUMMARY_EXIT_CODE_COLOR='31'
    fi

    if [ $PROMPT_SUMMARY_EXIT_CODE -gt 128 ]; then
        local SIGNAL_NO=$PROMPT_SUMMARY_EXIT_CODE
        (( SIGNAL_NO-=128 ))

        # Convert signal number to signal name.
        local SIGNAL_NAME=$(builtin kill -l $SIGNAL_NO 2>/dev/null)
        if [ $? -ne 0 ]; then
            SIGNAL_NAME='unknown signal'
        fi
        builtin echo -n $SIGNAL_NAME

        PROMPT_SUMMARY_EXIT_CODE="${PROMPT_SUMMARY_EXIT_CODE} ($(get_signal_name ${SIGNAL_NO}))"
    fi

    # Calculate differences between old and new timings.
    local I
    local J
    local DIFF_LIST=''
    local DIFF
    local NEW_TIMES=''
    local TEMP_VAR
    local TIME
    test ${SHELL_NAME} = 'zsh' && setopt sh_word_split
    local STAT=''
    builtin read STAT < /proc/${$}/stat
    I=0
    J=0
    for STAT_OPT in $STAT; do # Get the 4 timing values for the own pid.

        (( I++ ))
        if [ $I -lt 14 ]; then
            continue
        fi
        if [ $I -gt 17 ]; then
            break
        fi
        (( J++ ))
        (( TEMP_VAR = STAT_OPT - PROMPT_SUMMARY_LAST_TIME_USAGE[J] ))
        PROMPT_SUMMARY_TIME_DIFF[${J}]=${TEMP_VAR}
        PROMPT_SUMMARY_LAST_TIME_USAGE[$J]=${STAT_OPT}
    done
    test ${SHELL_NAME} = 'zsh' && unsetopt sh_word_split

    # Format /proc single digit time to format
    # [MINUTES]m[SECONDS].[MILLISECONDS]s
    I=76
    local LENGTH
    local TIME_MILLISECONDS
    local TIME_SECONDS
    local TIME_MINUTES
    test ${SHELL_NAME} = 'zsh' && setopt sh_word_split
    for TIME in ${PROMPT_SUMMARY_TIME_DIFF[3]} ${PROMPT_SUMMARY_TIME_DIFF[4]}; do
        LENGTH=${#TIME}
        while [ $LENGTH -lt 3 ]; do
            TIME="0$TIME"
            (( LENGTH++ ))
        done
        TIME_MILLISECONDS=${TIME: -2}
        TIME_SECONDS=${TIME:0:$LENGTH-2}
        (( TIME_MINUTES = TIME_SECONDS / 60 ))
        (( TIME_SECONDS = TIME_SECONDS % 60 ))
        PROMPT_SUMMARY_VARS[${I}]="${TIME_MINUTES}m${TIME_SECONDS}.${TIME_MILLISECONDS}s"
        (( I++ ))
    done
    test ${SHELL_NAME} = 'zsh' && unsetopt sh_word_split

    if [ "${PWD}" != "${PROMPT_SUMMARY_VARS[1]}" ]; then
        PROMPT_SUMMARY_VARS[1]="${PWD}"
    fi
}


# Command line interface to aftermath.
function aftermath {
    local HELP="

aftermath:
----------

aftermath COMMAND

Valid commands are:

       debug-vars :
              Print all variables. This includes configuration variables,
              runtime variables and all remaining internal state like
              temporary variables required to calculate durations.

       help | --help | -h :
              Print a short description of all aftermath commands.

"
    case ${1} in

        'debug-vars')
            local I=0

            while [ ${I} -le 80 ]; do
                if [ "${PROMPT_SUMMARY_VARS[${I}]}" != "" ]; then
                    echo "${I}: ${PROMPT_SUMMARY_VARS[${I}]}"
                fi
                (( I = I + 1 ))
            done
            ;;

        'help'|'--help'|'-h')
            echo ${HELP}
            ;;

        '')
            echo 'Missing parameter.' >&2
            echo
            echo ${HELP}
            return 1
            ;;

        *)
            echo "Invalid parameter: ${*}" >&2
            echo
            echo ${HELP}
            return 1
            ;;

    esac
}


PROMPT_COMMAND=pre_prompt


PROMPT_SUMMARY_VARS[14]="unknown"
case ${SHELL_NAME} in
    bash)
        PROMPT_SUMMARY_VARS[14]="bash"
        CURRENT_PATH="$(dirname ${BASH_SOURCE})"
        source "${CURRENT_PATH}/lib/bash.sh"
        ;;
    zsh)
        PROMPT_SUMMARY_VARS[14]="zsh"
        CURRENT_PATH="$(dirname $(readlink -e ${(%):-%x}))"
        source "${CURRENT_PATH}/lib/zsh.sh"
        ;;
esac


# Init variables.
for I in $(seq 4); do
    PROMPT_SUMMARY_LAST_TIME_USAGE[${I}]=0
done
PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH=0
PROMPT_SUMMARY_FILL_STRING=''
PROMPT_SUMMARY_VARS[11]=$(ps aux | grep ${$} | head -n 1 | sed -e 's/\ \+/\ /g' | cut -f 7 -d ' ') # Get own TTY
PROMPT_SUMMARY_VARS[12]="$(hostname)"

((
    PROMPT_SUMMARY_VARS[10]=
    ${#PROMPT_SUMMARY_VARS[11]}+
    ${#PROMPT_SUMMARY_VARS[12]}+
    ${#PROMPT_SUMMARY_VARS[14]}
))


# Default config values.
#   Colors:
AFTERMATH[default_background_color]='100'
AFTERMATH[default_decorator_color]='37'
AFTERMATH[default_field_name_color]='36'
AFTERMATH[default_field_value_color]='33'
AFTERMATH[default_field_error_value_color]='31'
#   Decorator elements:
AFTERMATH[default_decorator_start]='---=[ '
AFTERMATH[default_decorator_end]=' }=---'
AFTERMATH[default_decorator_field_separator]=' | '
AFTERMATH[default_decorator_line_fill]='-'
#   List of fields in order of visual representation:
AFTERMATH[default_decorator_line_fill]='ret user sys pid tty shell hostname dir'
#   Format string:
AFTERMATH[default_format_str]='' # Currently unused

# For each config variable that is not set by user, load default values.
#   Colors:
if [ -z "${AFTERMATH[background_color]}" ];          then AFTERMATH[background_color]="${AFTERMATH[default_background_color]}"; fi
if [ -z "${AFTERMATH[decorator_color]}" ];           then AFTERMATH[decorator_color]="${AFTERMATH[default_decorator_color]}"; fi
if [ -z "${AFTERMATH[field_name_color]}" ];          then AFTERMATH[field_name_color]="${AFTERMATH[default_field_name_color]}"; fi
if [ -z "${AFTERMATH[field_value_color]}" ];         then AFTERMATH[field_value_color]="${AFTERMATH[default_field_value_color]}"; fi
if [ -z "${AFTERMATH[field_error_value_color]}" ];   then AFTERMATH[field_error_value_color]="${AFTERMATH[default_field_error_value_color]}"; fi
#   Decorator elements:
if [ -z "${AFTERMATH[decorator_start]}" ];           then AFTERMATH[decorator_start]="${AFTERMATH[default_decorator_start]}"; fi
if [ -z "${AFTERMATH[decorator_end]}" ];             then AFTERMATH[decorator_end]="${AFTERMATH[default_decorator_end]}"; fi
if [ -z "${AFTERMATH[decorator_field_separator]}" ]; then AFTERMATH[decorator_field_separator]="${AFTERMATH[default_decorator_field_separator]}"; fi
if [ -z "${AFTERMATH[decorator_start]}" ];           then AFTERMATH[decorator_start]="${AFTERMATH[default_decorator_start]}"; fi
#   List of fields in order of visual representation:
if [ -z "${AFTERMATH[decorator_line_fill]}" ];       then AFTERMATH[decorator_line_fill]="${AFTERMATH[default_decorator_line_fill]}"; fi
#   Format string:
if [ -z "${AFTERMATH[format_str]}" ];                then AFTERMATH[format_str]="${AFTERMATH[default_format_str]}"; fi

