#!/bin/bash

# --- config ---
STATE_FILE="/tmp/audit_last_timestamp.txt"

# USER_CHAUTHTOK: change of password
# ADD_USER/DEL_USER/USER_MGMT: user changes
# SYSCALL: get notified when there are changes being made to sudoers/shadow
TYPES="USER_CHAUTHTOK,ADD_USER,DEL_USER,USER_MGMT,SYSCALL"

# --- Desktop-Notification ---
send_desktop_notify() {
    local title="$1"
    local message="$2"

    # active GUI-User
    local user=$(who | grep -m 1 '(:[0-9])' | awk '{print $1}')
    [ -z "$user" ] && user=$(loginctl list-users --no-legend | awk '{print $2}' | head -n 1)
    
    if [ -z "$user" ]; then
        echo "[ERROR] No active Sessions found."
        return
    fi

    local uid=$(id -u "$user")

    # Noticifations within the User-context 
    sudo -u "$user" \
        DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/"$uid"/bus \
        notify-send "$title" "$message" \
        -u critical \
        -i dialog-warning \
        -a "Audit-Wächter"
}

echo "[DEBUG] Checking audit logs for user and file changes..."

# Searching for events 
CHANGES=$(ausearch -m "$TYPES" -ts recent 2>/dev/null | grep -E "shadow|sudoers|USER_")

if [[ -n "$CHANGES" ]]; then
    
    # timestamps
    CURRENT_EVENT_TS=$(echo "$CHANGES" | grep "audit(" | tail -n 1 | awk -F'[(:]' '{print $2}')
    
    # load recent timestamp
    [ -f "$STATE_FILE" ] && LAST_EVENT_TS=$(cat "$STATE_FILE") || LAST_EVENT_TS="0"

    if [ "$CURRENT_EVENT_TS" != "$LAST_EVENT_TS" ]; then
        echo "[DEBUG] New relevant event detected!"

        # Detail-Extraction
        EVENT_TYPE=$(echo "$CHANGES" | grep -oP "type=\K[^ ]+" | tail -n 1)
        TARGET_USER=$(echo "$CHANGES" | grep -oP 'acct="\K[^"]+' | tail -n 1)
        [ -z "$TARGET_USER" ] && TARGET_USER=$(echo "$CHANGES" | grep -oP 'acct=\K[^ ]+' | tail -n 1)
        
        # (sudoers/shadow)
        if echo "$CHANGES" | grep -q "sudoers"; then
            DESC="CRITICAL: sudoers file has been changed!"
            TARGET_USER="System-Permissions"
        elif echo "$CHANGES" | grep -q "shadow"; then
            DESC="KRITISCH: shadow file (passwords) has been manipulated!"
            TARGET_USER="System-Passwords"
        else
            case $EVENT_TYPE in
                USER_CHAUTHTOK) DESC="Password has been changed";;
                ADD_USER)       DESC="User has been created";;
                DEL_USER)       DESC="User has been deleted";;
                USER_MGMT)      DESC="User-Modification";;
                *)              DESC="Security-Event ($EVENT_TYPE)";;
            esac
        fi

        MESSAGE="Action: $DESC"$'\n'"Details: $TARGET_USER"

        send_desktop_notify "Security-Alert" "$MESSAGE"
        echo "$CURRENT_EVENT_TS" > "$STATE_FILE"
    else
        echo "[DEBUG] Event already notified. Skipping."
    fi
else
    echo "[DEBUG] No critical changes found."
fi
