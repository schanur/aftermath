declare -a PROMPT_SUMMARY_LAST_TIME_USAGE
declare -a PROMPT_SUMMARY_TIME_DIFF


# Config
#   FORMAT_STR
#     Available format string variables:
#      ret                Return code of last command.
#      user_time          Userspace time of last processed command.
#      sys_time           Kernel time of last processed command.
#      pid                Process ID of this shell.
#      tty                Name of TTY/PTS that is used by this shell session.
#      shell              Running shell. Currently supported are Bash and Zsh.
#      hostname
#      dir                Current working directory.
#
# BACKGROUND_COLOR        Background color. Defaults to dark gray.
# DECORATOR_COLOR         Color of all characters that separates fields and decorates the line.
# FIELD_NAME_COLOR        Color of field name.
# FIELD_VALUE_COLOR       Color of field value
# FIELD_ERROR_VALUE_COLOR Color of a field when it tries to suggest an abnormal value (exit/return code != 0)

BG_COL_ESC='\033[1;100m'
BG_COL_RESET_ESC='\033[1;49m'
DECORATOR_COL_ESC='\033[1;37m'
FIELD_NAME_COL_ESC='\033[1;36m'
FIELD_VALUE_COL_ESC='\033[1;33m'
FG_COL_RESET_ESC='\033[1;'

# FIELD_NAME_COLOR
# Field_VALUE_COLOR

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

declare -A AFTERMATH
declare -a PROMPT_SUMMARY_VARS


if   [ -n "${BASH_VERSION}" ]; then
    SHELL_NAME="bash"
elif [ -n "${ZSH_VERSION}"  ]; then
    SHELL_NAME="zsh"
else
    echo "aftermath.sh: No supported shell (Currently supported: bash and zsh)"
    return
fi

AFTERMATH[shell_name]="${SHELL_NAME}"


# Calculate all variables which are later used by PROMPT_COMMAND. Then build the string which represents the whole aftermath line.
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

        PROMPT_SUMMARY_EXIT_CODE="${PROMPT_SUMMARY_EXIT_CODE} (${SIGNAL_NAME}))"
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
        if [ ${PROMPT_SUMMARY_VARS[${I}]} = "0m0.01s" ]; then
            PROMPT_SUMMARY_VARS[${I}]="0m0.00s"
        fi
        (( I++ ))
    done
    test ${SHELL_NAME} = 'zsh' && unsetopt sh_word_split

    if [ "${PWD}" != "${PROMPT_SUMMARY_VARS[1]}" ]; then
        PROMPT_SUMMARY_VARS[1]="${PWD}"
    fi


    # Calculate variable string length.
    ((
        AFTERMATH[field_value_length_sum]=
        ${#PROMPT_SUMMARY_EXIT_CODE}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${PROMPT_SUMMARY_VARS[10]}+
        ${#PROMPT_SUMMARY_VARS[1]}
    ))

    AFTERMATH[columns]=${COLUMNS}
    if [ ${AFTERMATH[field_value_length_sum]} -ne ${AFTERMATH[last_field_value_length_sum]} ] \
        || [ ${AFTERMATH[columns]} -ne ${AFTERMATH[columns]} ] ; then
        local FILL_STRING_LENGTH=${AFTERMATH[columns]}
        (( FILL_STRING_LENGTH -= (AFTERMATH[field_value_length_sum] + 100) ))
        AFTERMATH[fill_string]=${AFTERMATH[fill_string_stock]:0:${FILL_STRING_LENGTH}}
        AFTERMATH[last_field_value_length_sum]=${AFTERMATH[field_value_length_sum]}
        AFTERMATH[last_columns]=${AFTERMATH[columns]}
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

            case "${AFTERMATH[shell_name]}" in
                zsh)
                # Zsh array iteration
                # local DEBUG_VARS_ZSH_PROGRAM='
                # echo "###### ${AFTERMATH[#]} ######"
                # local aaa='for KEY VALUE in "${(kv)AFTERMATH[@]}"; do
                #     echo ">> $KEY = $VALUE <<"
                #     echo "---"
                # done'
                # eval $aaa
                # $DEBUG_VARS_ZSH_PROGRAM
                ;;
                bash)
                    # Bash array iteration
                    for KEY in "${!AFTERMATH[@]}"; do
                        echo "${KEY} = ${AFTERMATH[$KEY]}"
                    done
                    ;;
            esac
            ;;

        'help'|'--help'|'-h')
            echo ${HELP}
            ;;

        'private__color_num_to_esc_seq')
            if [ ${#} -eq 2 ]; then
                local COLOR_NUM="${2}"
                case "${AFTERMATH[shell_name]}" in
                    zsh)
                        local ESC_COLOR=$'\033[1;'
                        ESC_COLOR="${ESC_COLOR}${COLOR_NUM}mCOLOR"
                        echo "${ESC_COLOR}"
                        ;;
                    bash)
                        true
                        ;;
                esac
            fi
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


# Convert color configuration to escape sequence cache.

# BACKGROUND_COLOR        Background color. Defaults to dark gray.
# DECORATOR_COLOR         Color of all characters that separates fields and decorates the line.
# FIELD_NAME_COLOR        Color of field name.
# FIELD_VALUE_COLOR       Color of field value
# FIELD_ERROR_VALUE_COLOR

# BG_COL_ESC='\033[1;100m'
# BG_COL_RESET_ESC='\033[1;49m'
# DECORATOR_COL_ESC='\033[1;37m'
# FIELD_NAME_COL_ESC='\033[1;36m'
# FIELD_VALUE_COL_ESC='\033[1;33m'
# FG_COL_RESET_ESC='\033[1;'

AFTERMATH[last_columns]=0 # Track if terminal got resized.
AFTERMATH[last_field_value_length_sum]=0
AFTERMATH[fill_string_stock]="$(printf %300s |tr ' ' '-')"
AFTERMATH[fill_string]=${AFTERMATH[fill_string_stock]:0:10}


PROMPT_SUMMARY_VARS[14]="unknown"
case ${SHELL_NAME} in
    bash)
        PROMPT_SUMMARY_VARS[14]="bash"
        CURRENT_PATH="$(dirname ${BASH_SOURCE})"
        PROMPT_COMMAND="pre_prompt"
        ;;
    zsh)
        PROMPT_SUMMARY_VARS[14]="zsh"
        CURRENT_PATH="$(dirname $(readlink -e ${(%):-%x}))"
        source "${CURRENT_PATH}/lib/zsh.sh"
        ;;

esac

AFTERMATH[generated_line]=$'\033[1;100m\033[1;37m${AFTERMATH[fill_string]}---=[ \033[1;36mret: \033[1;${PROMPT_SUMMARY_EXIT_CODE_COLOR}m$PROMPT_SUMMARY_EXIT_CODE \033[1;37m| \033[1;36muser: \033[1;33m${PROMPT_SUMMARY_VARS[77]} \033[1;36msys: \033[1;33m${PROMPT_SUMMARY_VARS[76]} \033[1;37m| \033[1;36mpid: \033[1;33m$$ \033[1;37m| \033[1;36mtty: \033[1;33m${PROMPT_SUMMARY_VARS[11]} \033[1;37m| \033[1;36mshell: \033[1;33m${PROMPT_SUMMARY_VARS[14]} \033[1;37m| \033[1;36mhostname: \033[1;33m${PROMPT_SUMMARY_VARS[12]} \033[1;37m| \033[1;36mpath: \033[1;33m${PROMPT_SUMMARY_VARS[1]} \033[1;37m]=---\033[1;49m\n$(tput sgr0)'

case ${SHELL_NAME} in
    bash)
        PS1="${AFTERMATH[generated_line]}"
        ;;
    zsh)
        PROMPT="${AFTERMATH[generated_line]}"
        ;;
esac

# Init variables.
for I in $(seq 4); do
    PROMPT_SUMMARY_LAST_TIME_USAGE[${I}]=0
done
PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH=0
PROMPT_SUMMARY_FILL_STRING=''
PROMPT_SUMMARY_VARS[11]=$(ps aux | grep ${$} | head -n 1 | sed -e 's/\ \+/\ /g' | cut -f 7 -d ' ') # Get own TTY pid
PROMPT_SUMMARY_VARS[12]="$(hostname)"

((
    PROMPT_SUMMARY_VARS[10]=
    ${#PROMPT_SUMMARY_VARS[11]}+
    ${#PROMPT_SUMMARY_VARS[12]}+
    ${#PROMPT_SUMMARY_VARS[14]}
))
