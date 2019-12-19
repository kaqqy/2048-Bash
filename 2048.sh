#!/usr/bin/env bash

GW=4 # width of grid
GH=4 # height of grid
BW=7 # width of grid box
BH=3 # height of grid box
SW=$(($BW * $GW + $GW + 1)) # new screen width
SH=$(($BH * $GH + $GH + 6)) # new screen height
OSW=$(tput cols) # old screen width
OSH=$(tput lines) # old screen height

# initialize board values
for i in $(seq 0 $(($GH - 1)))
do
    for j in $(seq 0 $(($GW - 1)))
    do
        board[$(($GW * $i + $j))]=""
    done
done
num_filled=0 # spaces on the board that are filled
score=0

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
    local i
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

# Formats the screen and other settings
format ()
{
    tput smcup # show alternate screen
    printf "\e[8;${SH};${SW}t" # resize window
    tput clear # clears screen
    tput civis # hides cursor
    stty -echo # hides keyboard input
}

# Draws the gridlines
draw_grid ()
{
    boxline="repeat $BW 'printf q'"
    boxspace="repeat $BW 'printf \" \"'"
    gridline="printf t; repeat $(($GW - 1)) \"$boxline\" 'printf n'; $boxline; printf 'u\n'"
    gridspace="repeat $GW 'printf x' \"$(escape "$boxspace")\"; printf 'x\n'"
    gridrow="repeat $BH \"$(escape "$gridspace")\""
    tput setaf 243 # change text color
    tput setab 243 # change background color
    tput smacs # use alternate character set for drawing lines
    tput cup 1 0 # start from the second row
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
    tput rmacs # revert back to normal character set
    tput op # reset colors
}

# Writes the number $3 to the box at row $1 and col $2
update_box ()
{
    if [[ $# -ne 3 ]]
    then
        status_log "Error: Wrong number of arguments for update_box()"
        clean_exit
    elif [[ $1 -ge $GH ]] || [[ $1 -lt 0 ]] || [[ $2 -ge $GW ]] || [[ $2 -lt 0 ]]
    then
        status_log "Error: Out of bounds coordinates for update_box()"
        clean_exit
    fi
    local row=$(($1 * (1 + $BH) + 2))
    local col=$(($2 * (1 + $BW) + 1))
    if [[ $3 == "" ]]
    then
        tput setaf 247
        tput setab 247
    else
        local logtwo=0
        local num=$3
        while [[ $num -gt 1 ]]
        do
            num=$((num / 2))
            logtwo=$((logtwo + 1))
        done
        tput setab $logtwo
        tput setaf $((17 - logtwo))
    fi
    tput bold
    local i
    for i in $(seq 0 $(($BH - 1)))
    do
        tput cup $((row + $i)) $col
        printf "%${BW}s"
    done
    tput cup $(($row + $BH / 2)) $(($col + ($BW - ${#3}) / 2))
    printf "$3"
    tput sgr0 # reset bold text and color
}

# Setup the game
setup ()
{
    format
    tput cup 0 0
    tput bold
    echo "2048 game"
    tput sgr0
    tput cup $((SH - 4)) 0
    echo "Controls:"
    echo "WASD or arrow keys to move tiles"
    printf "Q to quit"
    draw_grid
}

# Undos the initial formatting and exits
clean_exit ()
{
    stty echo # shows keyboard input
    # tput init # resets terminal to default state
    tput op # reset any color/style changes
    tput cnorm # unhides cursor
    tput rmcup # hide alternate screen
    printf "\e[8;${OSH};${OSW}t" # resize window
    exit
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
    local incr=$((1 - 2 * ($1 % 2)))
    local i
    for i in $(seq $range_start $incr $range_end)
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
    local incr=$((1 - 2 * ($1 % 2)))
    local i
    for i in $(seq $range_start $incr $range_end)
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
                score=$((score + ${board[$(($GW * $row + $col))]}))
            fi
        fi
    done
}


# Updates all numbers on the board
update_board ()
{
    local i
    local j
    for i in $(seq 0 $(($GH - 1)))
    do
        for j in $(seq 0 $(($GW - 1)))
        do
            update_box $i $j "${board[$(($GW * $i + $j))]}"
        done
    done
}

# Updates the score
update_score ()
{
    local score_text="Score: $score"
    tput cup 0 $(($SW - ${#score_text}))
    printf "$score_text"
}

# Adds 2 or 4 randomly to the board
add_num_to_board ()
{
    if [[ $num_filled -ge $(($GW * $GH)) ]]
    then
        status_log "You lose"
        return
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
    board[$ind]=$((2 + 2 * (($RANDOM % 4) / 3)))
    num_filled=$((num_filled + 1))
}

setup

add_num_to_board
update_board
update_score

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
        update_score
        # check if game is over (all filled)
    fi
    read -n 1 -s char
done

clean_exit
