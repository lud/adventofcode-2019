#!/bin/sh
save_state=$(stty -g)
stty raw
mix run day13.exs 
stty "$save_state"