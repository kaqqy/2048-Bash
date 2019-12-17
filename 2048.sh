#!/usr/bin/env bash

GW=4 # width of grid
GH=4 # height of grid
BW=7 # width of grid box
BH=3 # height of grid box
SW=$(($BW * $GW + $GW + 1)) # new screen width
SH=$(($BH * $GH + $GH + 2)) # new screen height
OSW=$(tput cols) # old screen width
OSH=$(tput lines) # old screen height

# initialize board
for i in $(seq 0 $(($GH - 1)))
do
    for j in $(seq 0 $(($GW - 1)))
    do
        board[$(($GW * $i + $j))]=""
    done
done
num_filled=0 # spaces on the board that are filled

# Writes an status log message to the screen ()
status_log ()
{
    tput cup $(($SH - 1)) 0
    tput el
    printf "$@"
}

# Repeatedly calls commands passed as parameters
# Number of repetitions is the first parameter
# Rest of the parameters are evaluated
repeat ()
{
    if [[ $# -lt 1 ]]
    then
        status_log "Error: Not enough arguments for repeat()"
        clean_exit
    fi
    count=$1
    shift
    for i in $(seq "$count")
    do
        for cmd in "$@"
        do
            eval "$cmd"
        done
    done
}

# Escapes \ and " in a string
escape ()
{
    if [[ $# -ne 1 ]]
    then
        status_log "Error: Need exactly one argument for escape()"
        clean_exit
    fi
    echo $1 | sed 's/\(["\]\)/\\\1/g'
}

# Shift the numbers in the grid in the specified direction
shift_board ()
{
    if [[ $# -ne 1 ]]
    then
        status_log "Error: Wrong number of arguments for shift_board()"
        clean_exit
    fi
    # setup variables for handling all 4 directions at once
    # up = 0, down = 1, left = 2, right = 3
    local row_shift=$(((1 - $1 / 2) * (2 * $1 - 1)))
    local col_shift=$((($1 / 2) * (2 * $1 - 5)))
    # local ind_shift=$(((2 * ($1 % 2) - 1) * (1 + ($GW - 1) * (1 - $1 / 2))))
    local range_start=$((($1 % 2) * ($GW * $GH - 1)))
    local range_end=$(((1 - ($1 % 2)) * ($GW * $GH - 1)))
    for i in $(seq $range_start $range_end)
    do
        local prev_row=$(($i / $GW))
        local prev_col=$(($i % $GW))
        local row=$(($prev_row + $row_shift))
        local col=$(($prev_col + $col_shift))
        while [[ $row -ge 0 ]] && [[ $row -lt $GH ]] && [[ $col -ge 0 ]] && [[ $col -lt $GW ]]
        do
            if [[ "${board[$(($GW * $row + $col))]}" != "" ]]
            then
                break
            fi
            board[$(($GW * $row + $col))]="${board[$(($GW * $prev_row + $prev_col))]}"
            board[$(($GW * $prev_row + $prev_col))]=""
            prev_row=$row
            prev_col=$col
            row=$(($row + $row_shift))
            col=$(($col + $col_shift))
        done
    done
}

# Merges blocks on the board
merge_blocks ()
{
    if [[ $# -ne 1 ]]
    then
        status_log "Error: Wrong number of arguments for merge_blocks()"
        clean_exit
    fi
    # setup variables for handling all 4 directions at once
    # up = 0, down = 1, left = 2, right = 3
    local row_shift=$(((1 - $1 / 2) * (2 * $1 - 1)))
    local col_shift=$((($1 / 2) * (2 * $1 - 5)))
    # local ind_shift=$(((2 * ($1 % 2) - 1) * (1 + ($GW - 1) * (1 - $1 / 2))))
    local range_start=$((($1 % 2) * ($GW * $GH - 1)))
    local range_end=$(((1 - ($1 % 2)) * ($GW * $GH - 1)))
    for i in $(seq $range_start $range_end)
    do
        local prev_row=$(($i / $GW))
        local prev_col=$(($i % $GW))
        local row=$(($prev_row + $row_shift))
        local col=$(($prev_col + $col_shift))
        if [[ $row -ge 0 ]] && [[ $row -lt $GH ]] && [[ $col -ge 0 ]] && [[ $col -lt $GW ]]
        then
            if [[ "${board[$(($GW * $row + $col))]}" != "" ]] && [[ "${board[$(($GW * $row + $col))]}" -eq "${board[$(($GW * $prev_row + $prev_col))]}" ]]
            then
                board[$(($GW * $row + $col))]="$((2 * ${board[$(($GW * $row + $col))]}))"
                board[$(($GW * $prev_row + $prev_col))]=""
                num_filled=$((num_filled - 1))
            fi
        fi
    done
}

# Writes the number $3 to the box at row $1 and col $2
write_to_box ()
{
    if [[ $# -ne 3 ]]
    then
        status_log "Error: Wrong number of arguments for write_to_box()"
        clean_exit
    elif [[ $1 -ge $GH ]] || [[ $1 -lt 0 ]] || [[ $2 -ge $GW ]] || [[ $2 -lt 0 ]]
    then
        status_log "Error: Out of bounds coordinates for write_to_box()"
        clean_exit
    fi
    local row=$(($1 * (1 + $BH) + 1 + $BH / 2))
    local col=$(($2 * (1 + $BW) + 1))
    tput cup $row $col
    printf "%${BW}s"
    tput cup $row $(($col + ($BW - ${#3}) / 2))
    printf "$3"
}

# Updates all numbers on the board
counter=0
update_board ()
{
    counter=$((counter+1))
    status_log $counter
    for i in $(seq 0 $(($GH - 1)))
    do
        for j in $(seq 0 $(($GW - 1)))
        do
            write_to_box $i $j "${board[$(($GW * $i + $j))]}"
        done
    done
}

# Adds 2 or 4 randomly to the board
add_num_to_board ()
{
    if [[ $num_filled -ge $(($GW * $GH)) ]]
    then
        status_log "Error: Cannot add another number to the board since it's full"
        clean_exit
    fi
    local pos=$(($RANDOM % ($GW * GH - $num_filled) + 1))
    local ind=-1
    while [[ $pos -gt 0 ]]
    do
        ind=$(($ind + 1))
        if [[ ${board[$ind]} == "" ]]
        then
            pos=$(($pos - 1))
        fi
    done
    board[$ind]=$((2 + 2 * ($RANDOM % 2)))
    num_filled=$((num_filled + 1))
}

clean_exit ()
{
    stty echo # shows keyboard input
    tput op # reset any color/style changes
    tput cnorm # unhides cursor
    tput rmcup # hide alternate screen
    printf "\e[8;${OSH};${OSW}t" # resize window
    exit
}

tput smcup # show alternate screen
printf "\e[8;${SH};${SW}t" # resize window
tput clear # clears screen
tput civis # hides cursor
stty -echo # hides keyboard input
# tput setab 14 # change background color

# drawing the grid
boxline="repeat $BW 'printf q'"
boxspace="repeat $BW 'printf \" \"'"
gridline="printf t; repeat $(($GW - 1)) \"$boxline\" 'printf n'; $boxline; printf 'u\n'"
gridspace="repeat $GW 'printf x' \"$(escape "$boxspace")\"; printf 'x\n'"
gridrow="repeat $BH \"$(escape "$gridspace")\""
tput smacs
printf 'l'
repeat $(($GW - 1)) "$boxline" "printf w"
eval "$boxline"
printf 'k\n'
repeat $(($GH - 1)) "$gridrow" "$gridline"
eval "$gridrow"
printf 'm'
repeat $(($GW - 1)) "$boxline" "printf v"
eval "$boxline"
printf 'j'
tput rmacs

add_num_to_board
update_board

str="   "
read -n 1 -s char
while [[ $char != 'q' ]]
do
    str="${str:1}$char"
    update=1
    case $str in
        *w | $'\e[A')
            shift_board 0
            merge_blocks 0
            shift_board 0
            ;;
        *s | $'\e[B')
            shift_board 1
            merge_blocks 1
            shift_board 1
            ;;
        *d | $'\e[C')
            shift_board 3
            merge_blocks 3
            shift_board 3
            ;;
        *a | $'\e[D')
            shift_board 2
            merge_blocks 2
            shift_board 2
            ;;
        *)
            update=0
            ;;
    esac
    if [[ $update -eq 1 ]]
    then
        add_num_to_board
        update_board
        # check if game is over (all filled)
    fi
    read -n 1 -s char
done

clean_exit
