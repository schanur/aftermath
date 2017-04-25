
function to_lower () {
    echo $1 |tr "[:upper:]" "[:lower:]"
}

function print_login_summary () {

    echo -ne "date:\n  "
    date

    #echo -e "\ngroups:"
    #for ITEM in `id |awk '{print $3}' |sed -e 's/groups=//g' |sed -e 's/,/ /g'`; do
    #    echo "  `echo $ITEM |sed -e 's/(/ (/g'`"
    #done

    echo -e "\nlast logins:"
    local LOGIN_LINE=""
    while read LOGIN_LINE; do
        echo "  $LOGIN_LINE"
    done <<< "`lastlog |grep -v --color=never "**Never logged in**"`"

    echo -ne "\nmaschine:\n  "
    hostname

    echo -ne "\nnetwork devices:\n"
    local NETWORK_DEVICE=""
    for NETWORK_DEVICE in `cat /proc/net/dev |grep : |sed -e 's/:.*//g' |sed -e 's/\ *//g'`; do
        echo "  $NETWORK_DEVICE"
    done

    echo -ne "\nopen connections:\n"
    local CONNECTION=""
    while read CONNECTION; do
        echo "  $CONNECTION"
    done <<< "`netstat -n |grep ESTABLISHED |sed -e 's/ESTABLISHED//g' |sed -e 's/\ \ /\ /g'`"

    #free last lastb
}

function get_item_from_list () {
    local I=0
    local IN_LIST=0
    local ITEM_POSITION=0
    for ITEM in $*; do
        if [ $IN_LIST -eq 0 ]; then
            IN_LIST=1
            ITEM_POSITION=$ITEM
        else
            if [ $I -eq $ITEM_POSITION ]; then
                builtin echo $ITEM
            fi
            (( I++ ))
        fi
    done
}

function get_tty_for_pid () {
    while read PS_LINE; do
        if [ $(get_item_from_list 1 $PS_LINE) = $1 ]; then
            echo $(get_item_from_list 6 $PS_LINE)
            break
        fi
    done <<< "`ps aux`"
}

function init_prompt_summary () {
    PROMPT_SUMMARY_LAST_TIME_USAGE="0 0 0 0"
    PROMPT_SUMMARY_LAST_FILL_STRING_LENGTH=0
    PROMPT_SUMMARY_FILL_STRING=""
    PROMPT_SUMMARY_TTY=$(get_tty_for_pid $$)
    PROMPT_SUMMARY_STATIC_STRING_LENGTH=0
    local pid=$$
    (( PROMPT_SUMMARY_STATIC_STRING_LENGTH=${#PROMPT_SUMMARY_TTY} + ${#pid} ))

}

function get_times_for_pid () {
    local I=0
    local STAT=""
    builtin read STAT < /proc/$1/stat
    for STAT_OPT in $STAT; do
        (( I++ ))
        if [ $I -lt 14 ]; then
            continue
        fi
        if [ $I -gt 17 ]; then
            break
        fi
        builtin echo -n "$STAT_OPT "
    done
}

function get_signal_name () {
    local SIGNAL_NAME=$(builtin kill -l $1 2>/dev/null)
    if [ $? -ne 0 ]; then
        SIGNAL_NAME="unknown signal"
    fi
    builtin echo -n $SIGNAL_NAME
}

function calc_times_diff () {
    local I=0
    local DIFF_LIST=""
    local DIFF=""
    for TIME in $PROMPT_SUMMARY_LAST_TIME_USAGE; do
        local OLD_TIMES[$I]=$TIME
        (( I++ ))
    done
    I=0
    local NEW_TIMES=$(get_times_for_pid $$)
    for TIME in $NEW_TIMES; do
        let DIFF=$TIME-${OLD_TIMES[$I]}
        DIFF_LIST=$DIFF_LIST$DIFF
        if [ $I -lt 3 ]; then
            DIFF_LIST=$DIFF_LIST" "
        fi
        (( I++ ))
    done
    PROMPT_SUMMARY_LAST_TIME_USAGE=$NEW_TIMES
    PROMPT_SUMMARY_TIME_DIFF_LIST=$DIFF_LIST
}

function format_time () {
    local TIME=$1
    local LENGTH=${#TIME}
    while [ $LENGTH -lt 3 ]; do
        TIME="0$TIME"
        (( LENGTH++ ))
    done
    local TIME_MILLISECONDS=${TIME: -2}
    local TIME_SECONDS=${TIME:0:$LENGTH-2}
    local TIME_MINUTES=0
    (( TIME_MINUTES=$TIME_SECONDS/60 ))
    (( TIME_SECONDS%=60 ))
    builtin echo -n "${TIME_MINUTES}m${TIME_SECONDS}.${TIME_MILLISECONDS}s"
}

function get_time_diff_item () {
    local I=0
    for TIME in $PROMPT_SUMMARY_TIME_DIFF_LIST; do
        if [ $I -eq $1 ]; then
            builtin echo $TIME
            break
        fi
        (( I++ ))
    done
}

function color_per_exit_code () {
    if [ $PROMPT_SUMMARY_EXIT_CODE -eq 0 ]; then
        PROMPT_SUMMARY_EXIT_CODE_COLOR="33"
    else
        PROMPT_SUMMARY_EXIT_CODE_COLOR="31"
    fi
}

function calc_variable_string_length () {
    (( PROMPT_SUMMARY_STRING_LENGTH=
        ${#PROMPT_SUMMARY_EXIT_CODE}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_FORMATED_TIME_USER}+
        ${#PROMPT_SUMMARY_STATIC_STRING_LENGTH}
    ))
}

#11 $EXIT_CODE 15 $USER_TIME 6 $SYS_TIME 6 $FILL_STRING 11 $PID
function get_fill_string () {
    #return
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

function pre_prompt () {
    PROMPT_SUMMARY_EXIT_CODE=$(builtin echo $?)
    color_per_exit_code
    if [ $PROMPT_SUMMARY_EXIT_CODE -gt 128 ]; then
        if [ $(to_lower $PROMPT_SUMMARY_OPTION_SHOW_SIGNAL) = "yes" ]; then
            local SIGNAL_NO=$PROMPT_SUMMARY_EXIT_CODE
            (( SIGNAL_NO-=128 ))
            PROMPT_SUMMARY_EXIT_CODE="$PROMPT_SUMMARY_EXIT_CODE ($(get_signal_name $SIGNAL_NO))"
        fi
    fi
    calc_times_diff
    PROMPT_SUMMARY_FORMATED_TIME_USER=$(format_time $(get_time_diff_item 2))
    PROMPT_SUMMARY_FORMATED_TIME_SYS=$(format_time $(get_time_diff_item 3))
}

init_prompt_summary

PROMPT_COMMAND=pre_prompt

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
\[\033[1;33m\]$PROMPT_SUMMARY_TTY \
\[\033[1;37m\]]=\
$(get_fill_string)\n$(tput sgr0)'
#\[\03[39;49m\]'

#PROMPT_SUMMARY_STATS='\[\033[1;37m\]-=[ \
#\[\033[1;36m\]ret: \
#\[\033[1;${PROMPT_SUMMARY_EXIT_CODE_COLOR}m\]$PROMPT_SUMMARY_EXIT_CODE \
#\[\033[1;37m\]]=-=[ \
#\[\033[1;36m\]user: \
#\[\033[1;33m\]$PROMPT_SUMMARY_FORMATED_TIME_USER \
#\[\033[1;36m\]sys: \
#\[\033[1;33m\]$PROMPT_SUMMARY_FORMATED_TIME_SYS \
#\[\033[1;37m\]]=-$(get_fill_string)=[ \
#\[\033[1;36m\]pid: \
#\[\033[1;33m\]$$ \
#\[\033[1;36m\]tty: \
#\[\033[1;33m\]$PROMPT_SUMMARY_TTY \
#\[\033[1;37m\]]=-'

#if [ $(to_lower $PROMPT_SUMMARY_OPTION_PRINT_LOGIN) != "yes" ]; then
#    return
#fi

PROMPT_SUMMARY_LOADED=yes
