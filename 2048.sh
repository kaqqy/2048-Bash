#!/usr/bin/env bash

GW=4 # width of grid
GH=4 # height of grid
BW=7 # width of grid box
BH=3 # height of grid box
SW=$(($BW * $GW + $GW + 1)) # new screen width
SH=$(($BH * $GH + $GH + 1)) # new screen height
OSW=$(tput cols) # old screen width
OSH=$(tput lines) # old screen height

# Repeatedly calls commands passed as parameters
# Number of repetitions is the first parameter
# Rest of the parameters are evaluated
repeat ()
{
    if [[ $# -lt 1 ]]
    then
        echo "Error: Not enough arguments for repeat()"
        exit
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

escape ()
{
    if [[ $# -ne 1 ]]
    then
        echo "Error: Need exactly one argument for escape()"
        exit
    fi
    echo $1 | sed 's/\(["\]\)/\\\1/g'
}

tput smcup # show alternate screen
printf "\e[8;${SH};${SW}t" # resize window
tput clear

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

sleep 5
tput rmcup # hide alternate screen
printf "\e[8;${OSH};${OSW}t" # resize window
exit

#tput cup 10 10

exit

read -n 1 -s char
while [[ $char != 'q' ]]
do
    echo $char
    read -n 1 -s char
done
tput rmcup
exit
printf '\a'
sleep 5
printf '\e[2J'
#printf '\e[90A'
printf 'asdfasdf\n'
sleep 5
