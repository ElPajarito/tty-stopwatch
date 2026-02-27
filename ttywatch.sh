#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Script: ttywatch.sh
# Description: Aesthetic stopwatch with centered alignment, detailed dog, and 
#              dismissible MP3 timer alarm.
# -----------------------------------------------------------------------------

set -u

# --- Environment Setup ---
# Dynamically find the directory where this script lives
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# --- Visual Configuration ---
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
DIM=$(tput dim)
CLR_LINE=$(tput el)

# Define Baby Blue (Uses 256 colors if available, falls back to standard cyan)
BABY_BLUE=$(tput setaf 117 2>/dev/null || tput setaf 14)

# --- Defaults ---
GOAL_LABEL=""
PAUSED=false
START_TIME=$(date +%s)
TOTAL_PAUSE_OFFSET=0
LAST_PAUSE_START=0
LAP_COUNT=0

# Timer variables
TIMER_SECONDS=0
TIMER_TRIGGERED=false
ALARM_RINGING=false
ALARM_PID=""

# --- Functions ---

usage() {
    echo "${BOLD}Usage:${RESET} $0 [-g|--goal \"Goal Description\"] [-t|--timer minutes]"
    exit 1
}

cleanup() {
    tput cnorm # Restore cursor
    echo ""
    # Kill any active alarm audio on script exit
    if [[ -n "$ALARM_PID" ]]; then
        kill "$ALARM_PID" 2>/dev/null || true
    fi
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

play_random_sound() {
    # Force absolute path resolution based on script location
    local sounds_dir="${SCRIPT_DIR}/sounds"
    ALARM_PID="" # Reset PID
    
    # Check if directory exists
    if [[ -d "$sounds_dir" ]]; then
        # Enable nullglob so empty directories don't return the literal string
        shopt -s nullglob
        local mp3_files=("$sounds_dir"/*.mp3)
        shopt -u nullglob

        # If we found mp3 files
        if [[ ${#mp3_files[@]} -gt 0 ]]; then
            local random_idx=$(( RANDOM % ${#mp3_files[@]} ))
            local target_file="${mp3_files[$random_idx]}"
            
            # Cross-platform audio playback (run in background and grab PID)
            if command -v afplay &> /dev/null; then
                afplay "$target_file" &> /dev/null & ALARM_PID=$!
            elif command -v mpg123 &> /dev/null; then
                mpg123 -q "$target_file" &> /dev/null & ALARM_PID=$!
            elif command -v ffplay &> /dev/null; then
                ffplay -nodisp -autoexit "$target_file" &> /dev/null & ALARM_PID=$!
            elif command -v play &> /dev/null; then
                play -q "$target_file" &> /dev/null & ALARM_PID=$!
            fi
        fi
    fi
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
        1) echo "${COLOR}       __      _${RESET}" ;;
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
        3) echo "${COLOR}      \`_/      )${RESET}" ;;
        4) echo "${COLOR}      (_(_/-(_/${RESET}" ;;
    esac
}

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g|--goal) GOAL_LABEL="$2"; shift ;;
        -t|--timer) 
            # Validate input is a positive integer
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "${RED}Error: -t requires a whole number (minutes).${RESET}"
                exit 1
            fi
            TIMER_SECONDS=$(($2 * 60))
            shift 
            ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# --- Main Logic ---

tput civis # Hide cursor

# Initial Layout: Reserve 10 lines for the full UI
for i in {1..10}; do echo ""; done

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

    # --- Silent Timer Trigger ---
    if [[ "$TIMER_SECONDS" -gt 0 ]] && [[ "$TIMER_TRIGGERED" == false ]] && [[ "$ELAPSED" -ge "$TIMER_SECONDS" ]]; then
        TIMER_TRIGGERED=true
        ALARM_RINGING=true
        
        play_random_sound
        
        # Force a pause
        if [ "$PAUSED" = false ]; then
            PAUSED=true
            LAST_PAUSE_START=$CURRENT_TIME
            
            # Recalculate display states immediately to prevent lag
            ELAPSED=$((LAST_PAUSE_START - START_TIME - TOTAL_PAUSE_OFFSET))
            STATUS_INDICATOR="${BOLD}${RED}[PAUSED]${RESET}"
            DOG_STATE="paused"
        fi
    fi

    # --- Monitor Active Alarm ---
    # Automatically dismiss the "shut up" prompt if the song finishes on its own
    if [[ "$ALARM_RINGING" == true ]]; then
        if [[ -n "$ALARM_PID" ]]; then
            if ! kill -0 "$ALARM_PID" 2>/dev/null; then
                ALARM_RINGING=false 
            fi
        else
            # If no PID was captured (e.g. no MP3s found), auto-dismiss immediately
            ALARM_RINGING=false
        fi
    fi

    # --- Input Handling ---
    
    # Stop Audio (b)
    if [[ "$input_key" == "b" && "$ALARM_RINGING" == true ]]; then
        if [[ -n "$ALARM_PID" ]]; then
            kill "$ALARM_PID" 2>/dev/null || true
        fi
        ALARM_RINGING=false
    fi

    # Pause (p)
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

    # Lap (l)
    if [[ "$input_key" == "l" && "$PAUSED" == false ]]; then
        ((LAP_COUNT++))
        
        # Erase entire UI block (10 lines)
        tput cuu 10
        tput ed
        
        # Print Lap
        echo "${CYAN}Lap $LAP_COUNT: $(format_time "$ELAPSED")${RESET}"
        
        # Restore empty lines
        for i in {1..10}; do echo ""; done
    fi

    # --- Rendering ---
    
    GOAL_DISPLAY=""
    if [[ -n "$GOAL_LABEL" ]]; then
        GOAL_DISPLAY=" --> ${YELLOW}${GOAL_LABEL}${RESET}"
    fi

    tput sc # Save Cursor
    tput cuu 10 # Move UP 10 lines to top
    
    # 1. Spacer Line
    printf "\r${CLR_LINE}\n" 
    
    # 2. Timer Line (7 spaces padding to align with Dog center)
    printf "\r       ${BOLD}%s${RESET}%s %s${CLR_LINE}\n" "$(format_time "$ELAPSED")" "$GOAL_DISPLAY" "$STATUS_INDICATOR"
    
    # 3-6. Dog Lines
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 1)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 2)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 3)"
    printf "\r%s${CLR_LINE}\n" "$(get_dog_line "$ELAPSED" "$DOG_STATE" 4)"
    
    # 7. Spacer Line (Between Dog and Instructions)
    printf "\r${CLR_LINE}\n"
    
    # 8-9. Standard Instructions
    printf "\r${DIM}'${BOLD}p${RESET}${DIM}' to pause${RESET}${CLR_LINE}\n"
    printf "\r${DIM}'${BOLD}l${RESET}${DIM}' to lap${RESET}${CLR_LINE}\n"
    
    # 10. Dynamic Alarm Instruction
    if [[ "$ALARM_RINGING" == true ]]; then
        printf "\r${BABY_BLUE}'${BOLD}b${RESET}${BABY_BLUE}' to shut up timer${RESET}${CLR_LINE}"
    else
        printf "\r${CLR_LINE}" # Empty line to maintain layout height
    fi
    
    tput rc # Restore Cursor

done
