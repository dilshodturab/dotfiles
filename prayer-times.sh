#!/bin/bash

# Prayer Times for Waybar - Shows CURRENT prayer period
# Uses praytime.uz for Uzbekistan prayer times

REGION_ID=1  # 1 = Toshkent
CACHE_FILE="/tmp/prayer_times_praytime_cache.html"
LOCK_FILE="/tmp/prayer_times_update.lock"
CACHE_DURATION=10800  # 3 soat

# Fetch prayer times in background
fetch_prayer_times() {
    # Prevent multiple simultaneous updates
    if [ -f "$LOCK_FILE" ]; then
        return
    fi
    
    touch "$LOCK_FILE"
    curl -s "https://praytime.uz/?region_id=${REGION_ID}&lng=uz" > "$CACHE_FILE.tmp" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -s "$CACHE_FILE.tmp" ]; then
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    else
        rm -f "$CACHE_FILE.tmp"
    fi
    
    rm -f "$LOCK_FILE"
}

# Check if cache needs update
NEEDS_UPDATE=0
if [ ! -f "$CACHE_FILE" ]; then
    NEEDS_UPDATE=1
elif [ $(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) )) -gt $CACHE_DURATION ]; then
    NEEDS_UPDATE=1
fi

# Update in background if needed
if [ $NEEDS_UPDATE -eq 1 ]; then
    fetch_prayer_times &
    
    # If no cache exists, show loading and wait
    if [ ! -f "$CACHE_FILE" ]; then
        echo '{"text": "◐", "tooltip": "Namoz vaqtlari yuklanmoqda..."}'
        # Wait max 5 seconds for fetch to complete
        for i in {1..10}; do
            sleep 0.5
            if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
                break
            fi
        done
    fi
fi

# If still no cache, show error
if [ ! -f "$CACHE_FILE" ] || [ ! -s "$CACHE_FILE" ]; then
    echo '{"text": "🕌 --:--", "tooltip": "Internet aloqasi yo'\''q yoki praytime.uz ishlamayapti"}'
    exit 1
fi

# Parse HTML
# First, try to get all times using the standard (inactive) format. One will fail if it's active.
BOMDOD=$(grep -A2 '<b>Tong</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')
QUYOSH=$(grep -A2 '<b>Quyosh</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')
PESHIN=$(grep -A2 '<b>Peshin</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')
ASR=$(grep -A2 '<b>Asr</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')
SHOM=$(grep -A2 '<b>Shom</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')
XUFTON=$(grep -A2 '<b>Xufton</b>' "$CACHE_FILE" | grep 'class="time"' | sed 's/.*<div class="time">//;s/<\/div>.*//' | tr -d ' ')

# The active prayer has a different HTML structure. Find it and patch the correct variable.
# It's identified by `countdown-time` class for the time, and the name comes after it.
if grep -q '<div class="countdown-time">' "$CACHE_FILE"; then
    ACTIVE_TIME=$(grep '<div class="countdown-time">' "$CACHE_FILE" | sed -e 's/.*<div class="countdown-time">//' -e 's/<\/div>.*//' | tr -d ' ')
    ACTIVE_NAME=$(grep -A1 '<div class="countdown-time">' "$CACHE_FILE" | tail -n1 | sed -e 's/.*<div class="time">//' -e 's/<\/div>.*//' | tr -d ' ')

    case "$ACTIVE_NAME" in
        "Peshin") PESHIN=$ACTIVE_TIME ;;
        "Tong")   BOMDOD=$ACTIVE_TIME ;;
        "Quyosh") QUYOSH=$ACTIVE_TIME ;;
        "Asr")    ASR=$ACTIVE_TIME ;;
        "Shom")   SHOM=$ACTIVE_TIME ;;
        "Xufton") XUFTON=$ACTIVE_TIME ;;
    esac
fi

# Validation
if [ -z "$BOMDOD" ] || [ -z "$PESHIN" ] || [ -z "$ASR" ]; then
    echo '{"text": "🕌 --:--", "tooltip": "HTML parse xatosi"}'
    exit 1
fi

# Current time
CURRENT_TIME=$(date +%H:%M)

# Convert HH:MM to minutes, forcing base-10 interpretation to avoid octal errors (e.g. 08, 09)
time_to_minutes() {
    local hour=$(echo "$1" | cut -d: -f1)
    local minute=$(echo "$1" | cut -d: -f2)
    echo $(( (10#$hour * 60) + 10#$minute ))
}

CURRENT_MINUTES=$(time_to_minutes "$CURRENT_TIME")

# Parse all times
BOMDOD_MIN=$(time_to_minutes "$BOMDOD")
QUYOSH_MIN=$(time_to_minutes "$QUYOSH")
PESHIN_MIN=$(time_to_minutes "$PESHIN")
ASR_MIN=$(time_to_minutes "$ASR")
SHOM_MIN=$(time_to_minutes "$SHOM")
XUFTON_MIN=$(time_to_minutes "$XUFTON")

# Determine CURRENT prayer period (which prayer we should be praying now)
declare -A PRAYERS_MINS=(
    ["Bomdod"]="$BOMDOD_MIN"
    ["Ishrоq"]="$QUYOSH_MIN" # Ishroq starts at Quyosh time
    ["Peshin"]="$PESHIN_MIN"
    ["Asr"]="$ASR_MIN"
    ["Shom"]="$SHOM_MIN"
    ["Xufton"]="$XUFTON_MIN"
)

# Find the most recent prayer time that has passed
LAST_PRAYER_NAME="Xufton" # Default for times after midnight but before Bomdod
MAX_NEGATIVE_DIFF=-999999

# Handle the time between midnight and the first prayer (Bomdod)
if [ "$CURRENT_MINUTES" -lt "$BOMDOD_MIN" ]; then
    LAST_PRAYER_NAME="Xufton"
else
    # Find the latest prayer time that is not in the future
    for prayer in "Bomdod" "Ishrоq" "Peshin" "Asr" "Shom" "Xufton"; do
        prayer_minutes=${PRAYERS_MINS[$prayer]}
        
        # Skip if time is invalid
        if [ -z "$prayer_minutes" ] || [ "$prayer_minutes" -lt 0 ]; then
            continue
        fi

        diff=$((prayer_minutes - CURRENT_MINUTES))

        if [ $diff -le 0 ] && [ $diff -gt $MAX_NEGATIVE_DIFF ]; then
            MAX_NEGATIVE_DIFF=$diff
            LAST_PRAYER_NAME=$prayer
        fi
    done
fi

CURRENT_PRAYER=$LAST_PRAYER_NAME
if [ "$LAST_PRAYER_NAME" == "Ishrоq" ]; then
    # The current prayer name is just "Ishroq"
    CURRENT_PRAYER_DISPLAY="Ishrоq (Peshin oldidan)"
    # The tooltip should show the interval name
elif [ "$LAST_PRAYER_NAME" == "Bomdod" ]; then
    CURRENT_PRAYER_DISPLAY="Bomdod"
elif [ "$LAST_PRAYER_NAME" == "Peshin" ]; then
    CURRENT_PRAYER_DISPLAY="Peshin"
elif [ "$LAST_PRAYER_NAME" == "Asr" ]; then
    CURRENT_PRAYER_DISPLAY="Asr"
elif [ "$LAST_PRAYER_NAME" == "Shom" ]; then
    CURRENT_PRAYER_DISPLAY="Shom"
elif [ "$LAST_PRAYER_NAME" == "Xufton" ]; then
    CURRENT_PRAYER_DISPLAY="Xufton"
fi

# The text to display on the bar should be the name of the current prayer period
if [ "$LAST_PRAYER_NAME" == "Ishrоq" ]; then
    CURRENT_PRAYER="Ishrоq"
fi

# Find next prayer time (for tooltip info)
declare -A PRAYERS=(
    ["Bomdod"]="$BOMDOD"
    ["Peshin"]="$PESHIN"
    ["Asr"]="$ASR"
    ["Shom"]="$SHOM"
    ["Xufton"]="$XUFTON"
)

NEXT_PRAYER=""
NEXT_TIME=""
MIN_DIFF=99999

for prayer in Bomdod Peshin Asr Shom Xufton; do
    prayer_time="${PRAYERS[$prayer]}"
    [ -z "$prayer_time" ] && continue
    
    prayer_minutes=$(time_to_minutes "$prayer_time")
    diff=$((prayer_minutes - CURRENT_MINUTES))
    
    if [ $diff -lt 0 ]; then
        diff=$((diff + 1440))
    fi
    
    if [ $diff -lt $MIN_DIFF ] && [ $diff -ge 0 ]; then
        MIN_DIFF=$diff
        NEXT_PRAYER=$prayer
        NEXT_TIME=$prayer_time
    fi
done

if [ -z "$NEXT_PRAYER" ]; then
    NEXT_PRAYER="Bomdod"
    NEXT_TIME="$BOMDOD"
fi

# Calculate time remaining until next prayer
HOURS=$((MIN_DIFF / 60))
MINUTES=$((MIN_DIFF % 60))

if [ $HOURS -gt 0 ]; then
    TIME_REMAINING="${HOURS}s ${MINUTES}m"
else
    TIME_REMAINING="${MINUTES}m"
fi

# Build tooltip with all times
TOOLTIP="🕌 Bugungi namoz vaqtlari (Toshkent)\n\n"
TOOLTIP+="Bomdod:  ${BOMDOD}\n"
TOOLTIP+="Quyosh:  ${QUYOSH}\n"
TOOLTIP+="Peshin:  ${PESHIN}\n"
TOOLTIP+="Asr:     ${ASR}\n"
TOOLTIP+="Shom:    ${SHOM}\n"
TOOLTIP+="Xufton:  ${XUFTON}\n\n"
TOOLTIP+="Hozirgi namoz: ${CURRENT_PRAYER_DISPLAY}\n"
TOOLTIP+="Keyingi namoz: ${NEXT_PRAYER} ${NEXT_TIME} (${TIME_REMAINING} dan keyin)"

# Output for Waybar - showing CURRENT prayer period
echo "{\"text\": \"${CURRENT_PRAYER}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"prayer-time\"}"
