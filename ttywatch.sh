#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Script: stopwatch.sh
# Description: Aesthetic stopwatch with centered alignment and detailed dog.
# -----------------------------------------------------------------------------

set -u

# --- Visual Configuration ---
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
DIM=$(tput dim)
CLR_LINE=$(tput el)

# --- Defaults ---
GOAL_LABEL=""
PAUSED=false
START_TIME=$(date +%s)
TOTAL_PAUSE_OFFSET=0
LAST_PAUSE_START=0
LAP_COUNT=0

# --- Functions ---

usage() {
    echo "${BOLD}Usage:${RESET} $0 [-g|--goal \"Goal Description\"]"
    exit 1
}

cleanup() {
    tput cnorm # Restore cursor
    echo ""
    exit 0
}

trap cleanup SIGINT

format_time() {
    local total_seconds=$1
    local h=$((total_seconds / 3600))
    local m=$(( (total_seconds % 3600) / 60 ))
    local s=$((total_seconds % 60))
    printf "%02d:%02d:%02d" "$h" "$m" "$s"
}

get_dog_line() {
    local seconds=$1
    local state=$2
    local line_num=$3
    
    local frame=$((seconds % 2))
    
    local COLOR=$GREEN
    if [ "$state" == "paused" ]; then
        COLOR=$RED
    fi

    # Detailed Dog Art (Indented by default)
    case $line_num in
        1)
            echo "${COLOR}       __      _${RESET}"
            ;;
        2)
            if [ "$state" == "paused" ]; then
                echo "${COLOR}     o--)}____// ${DIM}zZz${RESET}"
            else
                if [ "$frame" -eq 0 ]; then
                    echo "${COLOR}     o'')}____//${RESET}"
                else
                    echo "${COLOR}     o'')}____\\\\${RESET}"
                fi
            fi
            ;;
        3)
             echo "${COLOR}      \`_/      )${RESET}"
             ;;
        4)
             echo "${COLOR}      (_(_/-(_/${RESET}"
             ;;
    esac
}

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g|--goal) GOAL_LABEL="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# --- Main Logic ---

tput civis # Hide cursor

# Initial Layout: Reserve 8 lines 
for i in {1..8}; do echo ""; done

while true; do
    CURRENT_TIME=$(date +%s)
    
    read -rsn1 -t 0.1 input_key || true

    # --- Calculation ---
    if [ "$PAUSED" = true ]; then
        ELAPSED=$((LAST_PAUSE_START - START_TIME - TOTAL_PAUSE_OFFSET))
        STATUS_INDICATOR="${BOLD}${RED}[PAUSED]${RESET}"
        DOG_STATE="paused"
    else
        ELAPSED=$((CURRENT_TIME - START_TIME - TOTAL_PAUSE_OFFSET))
        STATUS_INDICATOR=""
        DOG_STATE="running"
    fi

    # --- Input Handling ---
    if [[ "$input_key" == "p" ]]; then
        if [ "$PAUSED" = false ]; then
            PAUSED=true
            LAST_PAUSE_START=$CURRENT_TIME
        else
            PAUSED=false
            pause_duration=$((CURRENT_TIME - LAST_PAUSE_START))
            TOTAL_PAUSE_OFFSET=$((TOTAL_PAUSE_OFFSET + pause_duration))
        fi
    fi

    if [[ "$input_key" == "l" && "$PAUSED" == false ]]; then
        ((LAP_COUNT++))
        
        # Erase entire UI block (8 lines)
        tput cuu 8
        tput ed
        
        # Print Lap
        echo "${CYAN}Lap $LAP_COUNT: $(format_time "$ELAPSED")${RESET}"
        
        # Restore empty lines
        for i in {1..8}; do echo ""; done
    fi

    # --- Rendering ---
    
    GOAL_DISPLAY=""
    if [[ -n "$GOAL_LABEL" ]]; then
        GOAL_DISPLAY=" --> ${YELLOW}${GOAL_LABEL}${RESET}"
    fi

    tput sc # Save Cursor
    
    # Move UP 8 lines to top
    tput cuu 8
    
    # 1. Spacer Line
    printf "\r${CLR_LINE}\n" 
    
    # 2. Timer Line (Added 6 spaces padding to align with Dog center)
    printf "\r       ${BOLD}%s${RESET}%s %s${CLR_LINE}\n" "$(format_time "$ELAPSED")" "$GOAL_DISPLAY" "$STATUS_INDICATOR"
    
    # 3-6. Dog Lines
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 1)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 2)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 3)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 4)"
    
    # 7. Spacer Line (Between Dog and Instructions)
    printf "\r${CLR_LINE}\n"
    
    # 8. Instructions
    printf "\r${DIM}'${BOLD}p${RESET}${DIM}' to pause\n'${BOLD}l${RESET}${DIM}' to lap${RESET}${CLR_LINE}"
    
    tput rc # Restore Cursor

done
