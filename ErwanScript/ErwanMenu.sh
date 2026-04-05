#!/bin/bash

set -euo pipefail

USER_EXPIRY_FILE="${USER_EXPIRY_FILE:-/etc/ErwanScript/user-expiry.txt}"
MULTILOGIN_FILE="${MULTILOGIN_FILE:-/etc/ErwanScript/multilogin.txt}"
MULTILOGIN_DEFAULT_FILE="${MULTILOGIN_DEFAULT_FILE:-/etc/ErwanScript/multilogin-default.txt}"
XRAY_DIR="${XRAY_DIR:-/etc/ErwanScript}"
XRAY_MENU_DIR="${XRAY_MENU_DIR:-/etc/ErwanScript/XrayMenu}"
XRAY_CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
XRAY_EXPIRY_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"
XRAY_IP_LOCK_DIR="${XRAY_IP_LOCK_DIR:-/etc/ErwanScript/xray-ip-lock}"
XRAY_DISABLED_DIR="${XRAY_DISABLED_DIR:-/etc/ErwanScript/xray-disabled}"
USER_LOCK_DIR="${USER_LOCK_DIR:-/etc/ErwanScript/user-lock}"
SERVER_INFO_FILE="${SERVER_INFO_FILE:-/etc/ErwanScript/server-info.json}"
UDP_CONFIG_FILE="${UDP_CONFIG_FILE:-/etc/udp/config.json}"
WS_RESPONSE_FILE="${WS_RESPONSE_FILE:-/etc/ErwanScript/ws-response.txt}"
DEFAULT_WS_RESPONSE="<b><font color='#ff69b4'>CODEPINK</font> <font color='blue'>Protocol</font></b>"

mkdir -p /etc/ErwanScript
touch "$USER_EXPIRY_FILE" "$MULTILOGIN_FILE" "$MULTILOGIN_DEFAULT_FILE"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'
    C_BLUE=$'\033[38;5;39m'
    C_GREEN=$'\033[38;5;82m'
    C_YELLOW=$'\033[38;5;220m'
    C_RED=$'\033[38;5;203m'
    C_PANEL=$'\033[38;5;81m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_CYAN=""
    C_BLUE=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_PANEL=""
fi

MENU_ANIMATED="${MENU_ANIMATED:-0}"

pause() {
    read -r -p "Press Enter to continue..." _
}

open_menu_screen() {
    local title="${1:-Erwan Menu}"
    local frame
    clear
    for frame in "." ".." "..."; do
        printf "\r%bOpening %s%s%b" "$C_DIM$C_BLUE" "$title" "$frame" "$C_RESET"
        sleep 0.04
    done
    printf "\r%*s\r" 80 ""
    menu_line "=============================================================="
    printf "%b%s%b\n" "$C_BOLD$C_BLUE" "                     ${title}" "$C_RESET"
    menu_line "=============================================================="
    printf "%b%s%b\n" "$C_DIM" "Enter 0 on input prompts to go back." "$C_RESET"
    menu_line "------------------------------------------------------------"
}

run_limiters_now() {
    [ -x /etc/ErwanScript/limit-useradd.sh ] && /bin/bash /etc/ErwanScript/limit-useradd.sh >/dev/null 2>&1 || true
    [ -x /etc/ErwanScript/XrayMenu/limit-xray.sh ] && /bin/bash /etc/ErwanScript/XrayMenu/limit-xray.sh >/dev/null 2>&1 || true
}

menu_line() {
    printf "%b%s%b\n" "$C_PANEL" "$1" "$C_RESET"
}

menu_stat() {
    local label="$1"
    local value="$2"
    printf "%b%-14s%b %s\n" "$C_CYAN" "$label" "$C_RESET" "$value"
}

menu_stat_2col() {
    local left_label="$1"
    local left_value="$2"
    local right_label="$3"
    local right_value="$4"
    printf "%b%-14s%b %-18s  %b%-14s%b %s\n" \
        "$C_CYAN" "$left_label" "$C_RESET" "$left_value" \
        "$C_CYAN" "$right_label" "$C_RESET" "$right_value"
}

service_state_label() {
    local name="$1"
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        printf "%bRUNNING%b" "$C_GREEN" "$C_RESET"
    else
        printf "%bOFFLINE%b" "$C_RED" "$C_RESET"
    fi
}

animate_menu_intro() {
    local frames frame
    [ "$MENU_ANIMATED" = "0" ] || return 0
    MENU_ANIMATED=1
    frames='[■□□□□] [■■□□□] [■■■□□] [■■■■□] [■■■■■]'
    for frame in $frames; do
        printf "\r%bLaunching Erwan Menu %s%b" "$C_BLUE" "$frame" "$C_RESET"
        sleep 0.08
    done
    printf "\r%*s\r" 60 ""
}

confirm_prompt() {
    local prompt="$1"
    local answer
    read -r -p "$prompt [y/N]: " answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

valid_username() {
    [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_]{3,31}$ ]]
}

xray_user_exists() {
    local username="$1"
    [ -f "$XRAY_EXPIRY_FILE" ] && awk -v key="$username" '$1 == key { found=1 } END { exit(found ? 0 : 1) }' "$XRAY_EXPIRY_FILE"
}

create_xray_user_record() {
    local username="$1"
    local days="$2"
    local uuid expiry tmpfile

    if [ ! -f "$XRAY_CONFIG" ]; then
        echo "Xray config not found: $XRAY_CONFIG"
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required to create Xray users."
        return 1
    fi
    if xray_user_exists "$username"; then
        echo "Xray user already exists."
        return 1
    fi

    uuid="$(cat /proc/sys/kernel/random/uuid)"
    expiry="$(date -d "+${days} days" +%Y-%m-%d)"
    tmpfile="$(mktemp)"

    if ! jq --arg user "$username" --arg uuid "$uuid" '
      (.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"name":$user,"email":$user,"id":$uuid}] |
      (.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"name":$user,"email":$user,"id":$uuid}] |
      (.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password":$uuid,"email":$user}] |
      (.inbounds[] | select(.protocol=="shadowsocks")) |= (
        .settings.clients += [{
          method: (.settings.method // "aes-128-gcm"),
          password: $uuid,
          email: $user
        }]
      )
    ' "$XRAY_CONFIG" > "$tmpfile"; then
        rm -f "$tmpfile"
        echo "Failed to update Xray config."
        return 1
    fi

    chown --reference="$XRAY_CONFIG" "$tmpfile"
    chmod --reference="$XRAY_CONFIG" "$tmpfile"
    mv "$tmpfile" "$XRAY_CONFIG"
    chown root:root "$XRAY_CONFIG"
    chmod 0644 "$XRAY_CONFIG"

    mkdir -p "$(dirname "$XRAY_EXPIRY_FILE")"
    echo "$username $expiry" >> "$XRAY_EXPIRY_FILE"
    systemctl restart xray

    echo "Xray user created."
    echo "Xray UUID : $uuid"
    echo "Xray Expiry : $expiry"
}

list_xray_users() {
    if [ ! -f "$XRAY_CONFIG" ] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    jq -r '.inbounds[] | select(.settings.clients != null) | .settings.clients[] | (.name // .email // empty)' "$XRAY_CONFIG" 2>/dev/null | sort -u
}

delete_xray_user_record() {
    local username="$1"
    local tmpfile

    if [ ! -f "$XRAY_CONFIG" ] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    if [ -f "$XRAY_EXPIRY_FILE" ]; then
        awk -v user="$username" '$1 != user' "$XRAY_EXPIRY_FILE" > "${XRAY_EXPIRY_FILE}.tmp"
        mv "${XRAY_EXPIRY_FILE}.tmp" "$XRAY_EXPIRY_FILE"
    fi

    tmpfile="$(mktemp)"
    if jq --arg user "$username" '
      (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |=
        map(select((.name // .email // "") != $user))
    ' "$XRAY_CONFIG" > "$tmpfile"; then
        chown --reference="$XRAY_CONFIG" "$tmpfile"
        chmod --reference="$XRAY_CONFIG" "$tmpfile"
        mv "$tmpfile" "$XRAY_CONFIG"
        chown root:root "$XRAY_CONFIG"
        chmod 0644 "$XRAY_CONFIG"
        systemctl restart xray >/dev/null 2>&1 || true
    else
        rm -f "$tmpfile"
        return 1
    fi
}

rename_xray_user_record() {
    local old_username="$1"
    local new_username="$2"
    local tmpfile

    if [ ! -f "$XRAY_CONFIG" ] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    tmpfile="$(mktemp)"
    if jq --arg old "$old_username" --arg new "$new_username" '
      (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess") | .settings.clients) |=
        map(if (.name // .email // "") == $old then .name = $new | .email = $new else . end) |
      (.inbounds[] | select(.protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |=
        map(if (.email // "") == $old then .email = $new else . end)
    ' "$XRAY_CONFIG" > "$tmpfile"; then
        chown --reference="$XRAY_CONFIG" "$tmpfile"
        chmod --reference="$XRAY_CONFIG" "$tmpfile"
        mv "$tmpfile" "$XRAY_CONFIG"
        chown root:root "$XRAY_CONFIG"
        chmod 0644 "$XRAY_CONFIG"
        if [ -f "$XRAY_EXPIRY_FILE" ]; then
            replace_record_key "$XRAY_EXPIRY_FILE" "$old_username" "$new_username $(awk -v key="$old_username" '$1 == key { print $2 }' "$XRAY_EXPIRY_FILE" | head -n 1)"
        fi
        systemctl restart xray >/dev/null 2>&1 || true
    else
        rm -f "$tmpfile"
        return 1
    fi
}

xray_expiry() {
    local username="$1"
    [ -f "$XRAY_EXPIRY_FILE" ] && awk -v key="$username" '$1 == key { print $2; exit }' "$XRAY_EXPIRY_FILE"
}

list_panel_users() {
    awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" { print $1 }' /etc/passwd
}

replace_record_key() {
    local file="$1"
    local old_key="$2"
    local new_line="$3"
    awk -v key="$old_key" -v line="$new_line" '
        $1 == key { if (!done) { print line; done=1 } next }
        { print }
        END { if (!done && line != "") print line }
    ' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
}

delete_record_key() {
    local file="$1"
    local old_key="$2"
    awk -v key="$old_key" '$1 != key { print }' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
}

user_expiry() {
    local username="$1"
    chage -l "$username" 2>/dev/null | awk -F': ' '/Account expires/ { print $2 }'
}

sync_user_expiry_file() {
    local username="$1"
    local expiry
    expiry="$(user_expiry "$username")"
    if [ -n "$expiry" ] && [ "$expiry" != "never" ] && [ "$expiry" != "Never" ]; then
        replace_record_key "$USER_EXPIRY_FILE" "$username" "$username $expiry"
    else
        delete_record_key "$USER_EXPIRY_FILE" "$username"
    fi
}

create_user() {
    local username password days expiry mode create_ssh=0 create_xray=0
    echo "Create Mode"
    echo "1. SSH/OVPN only"
    echo "2. Xray only"
    echo "3. Both"
    read -r -p "Select mode [3]: " mode
    [ "$mode" = "0" ] && return
    case "${mode:-3}" in
        1) create_ssh=1 ;;
        2) create_xray=1 ;;
        3) create_ssh=1; create_xray=1 ;;
        *) echo "Invalid option."; return ;;
    esac

    read -r -p "Username: " username
    [ "$username" = "0" ] && return
    if ! valid_username "$username"; then
        echo "Invalid username. It must be alphanumeric, start with a letter, and be at least 4 characters."
        return
    fi
    if [ "$create_ssh" -eq 1 ] && id "$username" >/dev/null 2>&1; then
        echo "SSH/OVPN username already exists."
        return
    fi
    if [ "$create_xray" -eq 1 ] && xray_user_exists "$username"; then
        echo "Xray username already exists."
        return
    fi
    if [ "$create_ssh" -eq 1 ]; then
        read -r -p "Password: " password
        [ "$password" = "0" ] && return
        if [ "${#password}" -lt 4 ]; then
            echo "Invalid password. Must be at least 4 characters."
            return
        fi
    fi
    read -r -p "Days until expiration: " days
    [ "$days" = "0" ] && return
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -le 0 ]; then
        echo "Invalid day input."
        return
    fi
    if [ "$create_ssh" -eq 1 ]; then
        expiry="$(date -d "+${days} days" +%Y-%m-%d)"
        useradd -m -s /bin/bash -e "$expiry" "$username"
        echo "${username}:${password}" | chpasswd
        sync_user_expiry_file "$username"
        echo "SSH/OVPN user created."
        echo "SSH/OVPN Expiry : $expiry"
    fi
    if [ "$create_xray" -eq 1 ]; then
        create_xray_user_record "$username" "$days" || return
    fi
}

delete_user() {
    local mode username
    echo "Delete Mode"
    echo "1. Single user"
    echo "2. All users"
    read -r -p "Select option [1]: " mode
    [ "$mode" = "0" ] && return

    case "${mode:-1}" in
        1)
            read -r -p "Enter username to remove: " username
            [ "$username" = "0" ] && return
            if ! id "$username" >/dev/null 2>&1 && ! xray_user_exists "$username"; then
                echo "User does not exist."
                return
            fi
            if id "$username" >/dev/null 2>&1; then
                userdel -f "$username" >/dev/null 2>&1 || true
                delete_record_key "$USER_EXPIRY_FILE" "$username"
                delete_record_key "$MULTILOGIN_FILE" "$username"
            fi
            if xray_user_exists "$username"; then
                delete_xray_user_record "$username" || {
                    echo "Failed to remove Xray user."
                    return
                }
            fi
            echo "Deleted."
            ;;
        2)
            delete_all_users
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

edit_user() {
    local old_username new_username
    read -r -p "User: Old : " old_username
    [ "$old_username" = "0" ] && return
    if ! id "$old_username" >/dev/null 2>&1 && ! xray_user_exists "$old_username"; then
        echo "User does not exist."
        return
    fi
    read -r -p "User: New : " new_username
    [ "$new_username" = "0" ] && return
    if ! valid_username "$new_username"; then
        echo "Invalid username. It must be alphanumeric, start with a letter, and be at least 4 characters."
        return
    fi
    if id "$new_username" >/dev/null 2>&1 || xray_user_exists "$new_username"; then
        echo "Username already exists."
        return
    fi
    if id "$old_username" >/dev/null 2>&1; then
        usermod -l "$new_username" "$old_username"
        sync_user_expiry_file "$new_username"
        delete_record_key "$USER_EXPIRY_FILE" "$old_username"
        if awk -v key="$old_username" '$1 == key { found=1 } END { exit(found ? 0 : 1) }' "$MULTILOGIN_FILE"; then
            local value
            value="$(awk -v key="$old_username" '$1 == key { print $2 }' "$MULTILOGIN_FILE" | head -n 1)"
            replace_record_key "$MULTILOGIN_FILE" "$old_username" "$new_username ${value:-1}"
        fi
    fi
    if xray_user_exists "$old_username"; then
        rename_xray_user_record "$old_username" "$new_username" || {
            echo "Failed to rename Xray user."
            return
        }
    fi
    echo "User updated."
}

list_users() {
    local found=0
    local all_users
    all_users="$(
        {
            list_panel_users
            list_xray_users
        } | awk 'NF' | sort -u
    )"
    printf "%-20s | %-8s | %-8s | %-20s\n" "Username" "SSH/OVPN" "Xray" "Expiry"
    printf '%s\n' "---------------------+----------+----------+----------------------"
    while IFS= read -r username; do
        local ssh_flag="No"
        local xray_flag="No"
        local expiry=""
        [ -z "$username" ] && continue
        found=1
        if id "$username" >/dev/null 2>&1; then
            ssh_flag="Yes"
            expiry="$(user_expiry "$username")"
        fi
        if xray_user_exists "$username"; then
            xray_flag="Yes"
            if [ -z "$expiry" ]; then
                expiry="$(xray_expiry "$username")"
            fi
        fi
        printf "%-20s | %-8s | %-8s | %-20s\n" "$username" "$ssh_flag" "$xray_flag" "${expiry:-N/A}"
    done <<< "$all_users"
    [ "$found" -eq 1 ] || echo "No users found."
}

delete_all_users() {
    if ! confirm_prompt "Delete all SSH/OVPN and Xray users"; then
        echo "Cancelled."
        return
    fi
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        userdel -f "$username" >/dev/null 2>&1 || true
    done < <(list_panel_users)
    : > "$USER_EXPIRY_FILE"
    : > "$MULTILOGIN_FILE"
    if [ -f "$XRAY_CONFIG" ] && command -v jq >/dev/null 2>&1; then
        local value
        value="$(mktemp)"
        if jq '
          (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |= []
        ' "$XRAY_CONFIG" > "$value"; then
            chown --reference="$XRAY_CONFIG" "$value"
            chmod --reference="$XRAY_CONFIG" "$value"
            mv "$value" "$XRAY_CONFIG"
            chown root:root "$XRAY_CONFIG"
            chmod 0644 "$XRAY_CONFIG"
            : > "$XRAY_EXPIRY_FILE"
            systemctl restart xray >/dev/null 2>&1 || true
        else
            rm -f "$value"
        fi
    fi
    echo "All users deleted."
}

show_expirations() {
    if [ ! -s "$USER_EXPIRY_FILE" ] && [ ! -s "$XRAY_EXPIRY_FILE" ]; then
        echo "No expirations recorded."
        return
    fi
    printf "%-20s | %-8s | %-20s\n" "Username" "Type" "Expiration"
    printf '%s\n' "---------------------+----------+----------------------"
    if [ -s "$USER_EXPIRY_FILE" ]; then
        while read -r username expiry; do
            [ -z "$username" ] && continue
            printf "%-20s | %-8s | %-20s\n" "$username" "SSH" "$expiry"
        done < "$USER_EXPIRY_FILE"
    fi
    if [ -s "$XRAY_EXPIRY_FILE" ]; then
        while read -r username expiry; do
            [ -z "$username" ] && continue
            printf "%-20s | %-8s | %-20s\n" "$username" "Xray" "$expiry"
        done < "$XRAY_EXPIRY_FILE"
    fi
}

change_password() {
    local username password
    read -r -p "Username: " username
    [ "$username" = "0" ] && return
    if ! id "$username" >/dev/null 2>&1; then
        echo "User does not exist."
        return
    fi
    read -r -s -p "New Password: " password
    echo
    [ "$password" = "0" ] && return
    if [ "${#password}" -lt 4 ]; then
        echo "Invalid password. Must be at least 4 characters."
        return
    fi
    echo "${username}:${password}" | chpasswd
    echo "Password changed successfully."
}

extend_expiration() {
    local username days current expiry_ts new_expiry
    read -r -p "Enter Username: " username
    [ "$username" = "0" ] && return
    if ! id "$username" >/dev/null 2>&1 && ! xray_user_exists "$username"; then
        echo "User does not exist."
        return
    fi
    read -r -p "Days to extend: " days
    [ "$days" = "0" ] && return
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -le 0 ]; then
        echo "Invalid day input."
        return
    fi
    if id "$username" >/dev/null 2>&1; then
        current="$(user_expiry "$username")"
        if [ -z "$current" ] || [ "$current" = "never" ] || [ "$current" = "Never" ]; then
            expiry_ts="$(date +%s)"
        else
            expiry_ts="$(date -d "$current" +%s)"
        fi
        new_expiry="$(date -d "@$((expiry_ts + days * 86400))" +%Y-%m-%d)"
        chage -E "$new_expiry" "$username"
        sync_user_expiry_file "$username"
    fi
    if xray_user_exists "$username"; then
        current="$(xray_expiry "$username")"
        if [ -z "$current" ]; then
            expiry_ts="$(date +%s)"
        else
            expiry_ts="$(date -d "$current" +%s)"
        fi
        new_expiry="$(date -d "@$((expiry_ts + days * 86400))" +%Y-%m-%d)"
        replace_record_key "$XRAY_EXPIRY_FILE" "$username" "$username $new_expiry"
    fi
    echo "Expiration extended!!!"
}

change_multilogin() {
    local username limit scope all_users
    echo "Change Multilogin"
    echo "1. Single user"
    echo "2. All users and future accounts"
    read -r -p "Select option [1]: " scope
    [ "$scope" = "0" ] && return
    read -r -p "Connection limit: " limit
    [ "$limit" = "0" ] && return
    if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -le 0 ]; then
        echo "Invalid option. Try again."
        return
    fi
    case "${scope:-1}" in
        1)
            read -r -p "Username: " username
            [ "$username" = "0" ] && return
            if ! id "$username" >/dev/null 2>&1 && ! xray_user_exists "$username"; then
                echo "User does not exist."
                return
            fi
            replace_record_key "$MULTILOGIN_FILE" "$username" "$username $limit"
            echo "Successfully changed."
            ;;
        2)
            printf '%s\n' "$limit" > "$MULTILOGIN_DEFAULT_FILE"
            all_users="$(
                {
                    list_panel_users
                    list_xray_users
                } | awk 'NF' | sort -u
            )"
            while IFS= read -r username; do
                [ -n "$username" ] || continue
                replace_record_key "$MULTILOGIN_FILE" "$username" "$username $limit"
            done <<< "$all_users"
            echo "Global multilogin updated."
            echo "All current users were updated, and new accounts will follow this default."
            ;;
        *)
            echo "Invalid option. Try again."
            return
            ;;
    esac
    echo "The new limit will be applied automatically by cron."
    run_limiters_now
    echo "Limiters were also triggered now."
}

change_hysteria_obfs() {
    local current new_value

    current="viperpanel"
    if [ -f "$UDP_CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        current="$(jq -r '.obfs // "viperpanel"' "$UDP_CONFIG_FILE" 2>/dev/null)"
    elif [ -f "$SERVER_INFO_FILE" ] && command -v jq >/dev/null 2>&1; then
        current="$(jq -r '.udp_hysteria_obfs // "viperpanel"' "$SERVER_INFO_FILE" 2>/dev/null)"
    fi

    echo "Current Hysteria obfs: $current"
    read -r -p "New Hysteria obfs: " new_value
    if [ -z "$new_value" ] || [ "$new_value" = "0" ]; then
        echo "Cancelled."
        return
    fi

    if [ -f "$UDP_CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        local tmpfile
        tmpfile="$(mktemp)"
        if jq --arg obfs "$new_value" '.obfs = $obfs' "$UDP_CONFIG_FILE" > "$tmpfile"; then
            mv "$tmpfile" "$UDP_CONFIG_FILE"
            chmod 0644 "$UDP_CONFIG_FILE"
        else
            rm -f "$tmpfile"
            echo "Failed to update $UDP_CONFIG_FILE"
            return
        fi
    fi

    if [ -f "$SERVER_INFO_FILE" ] && command -v jq >/dev/null 2>&1; then
        local info_tmp
        info_tmp="$(mktemp)"
        if jq --arg obfs "$new_value" '.udp_hysteria_obfs = $obfs' "$SERVER_INFO_FILE" > "$info_tmp"; then
            mv "$info_tmp" "$SERVER_INFO_FILE"
            chmod 0644 "$SERVER_INFO_FILE"
        else
            rm -f "$info_tmp"
        fi
    fi

    systemctl restart udp >/dev/null 2>&1 || true
    echo "Hysteria obfs updated to: $new_value"
}

change_ws_response() {
    local current mode new_value
    local first_text first_color second_text second_color

    current="$DEFAULT_WS_RESPONSE"
    if [ -f "$WS_RESPONSE_FILE" ] && [ -s "$WS_RESPONSE_FILE" ]; then
        current="$(cat "$WS_RESPONSE_FILE")"
    fi

    echo "Current WS 101 response:"
    echo "$current"
    echo
    echo "This setting is global."
    echo "Per-user WS 101 response is not supported because the 101 reply happens before SSH/OVPN username auth is known."
    echo
    echo "1. Guided text + color editor"
    echo "2. Raw HTML"
    echo "0. Back"
    read -r -p "Select mode [1]: " mode
    [ "$mode" = "0" ] && return
    mode="${mode:-1}"

    case "$mode" in
        1)
            read -r -p "First text [CODEPINK]: " first_text
            [ "$first_text" = "0" ] && return
            read -r -p "First color [#ff69b4]: " first_color
            [ "$first_color" = "0" ] && return
            read -r -p "Second text [Protocol]: " second_text
            [ "$second_text" = "0" ] && return
            read -r -p "Second color [blue]: " second_color
            [ "$second_color" = "0" ] && return

            first_text="${first_text:-CODEPINK}"
            first_color="${first_color:-#ff69b4}"
            second_text="${second_text:-Protocol}"
            second_color="${second_color:-blue}"
            new_value="<b><font color='${first_color}'>${first_text}</font> <font color='${second_color}'>${second_text}</font></b>"
            ;;
        2)
            read -r -p "New WS 101 response HTML: " new_value
            [ "$new_value" = "0" ] && return
            if [ -z "$new_value" ]; then
                echo "Cancelled."
                return
            fi
            ;;
        *)
            echo "Invalid option."
            return
            ;;
    esac

    printf '%s\n' "$new_value" > "$WS_RESPONSE_FILE"
    chmod 0644 "$WS_RESPONSE_FILE"
    systemctl restart ErwanWS >/dev/null 2>&1 || true
    echo "WS 101 response updated."
    echo "Saved value:"
    echo "$new_value"
}

restart_service_menu() {
    local services=(
        "ssh"
        "erwanssh"
        "ErwanWS"
        "ErwanTCP"
        "ErwanTLS"
        "ErwanDNS"
        "ErwanDNSTT"
        "nginx"
        "xray"
        "squid"
        "udp"
        "stunnel4"
        "openvpn-server@tcp"
        "openvpn-server@udp"
        "badvpn-udpgw"
        "ddos"
    )
    local i choice service
    echo "Select a Service to Restart"
    for i in "${!services[@]}"; do
        printf "%2d. %s\n" "$((i + 1))" "${services[$i]}"
    done
    echo " 0. Back"
    read -r -p "Select an option: " choice
    [ "$choice" = "0" ] && return
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#services[@]}" ]; then
        echo "Invalid option. Try again."
        return
    fi
    service="${services[$((choice - 1))]}"
    echo "Restarting ${service}..."
    systemctl restart "$service"
    echo "Success"
}

restart_all_services() {
    local service
    echo "Restarting All Services..."
    for service in ssh erwanssh ErwanWS ErwanTCP ErwanTLS ErwanDNS ErwanDNSTT nginx xray squid udp stunnel4 openvpn-server@tcp openvpn-server@udp badvpn-udpgw ddos; do
        systemctl restart "$service" >/dev/null 2>&1 || true
    done
    echo "All Services Restarted"
}

show_openvpn_links() {
    local domain
    domain="$(cat /etc/ErwanScript/domain 2>/dev/null || echo "")"
    if [ -z "$domain" ]; then
        echo "Domain is not configured."
        return
    fi
    echo "OpenVPN Download Links"
    echo "TCP OVPN : https://${domain}:777/openvpn/tcp.ovpn"
    echo "UDP OVPN : https://${domain}:777/openvpn/udp.ovpn"
    echo "CA Cert  : https://${domain}:777/openvpn/ca.crt"
    echo
    echo "Recommended OpenVPN Flow"
    echo "TCP Direct : ${domain}:1194"
    echo "UDP Direct : ${domain}:110"
    echo
    echo "SSH Flow Stays Separate"
    echo "SSH Direct : ${domain}:22"
    echo "SSL Direct : ${domain}:111 or ${domain}:443"
    echo "Admin SSH  : ${domain}:2222"
}

show_protocol_matrix() {
    local domain
    domain="$(cat /etc/ErwanScript/domain 2>/dev/null || echo "your-domain")"
    cat <<EOF
Verified Protocol Matrix

SSH
- Direct Connection        : ${domain}:22
- HTTP + Proxy            : proxy ${domain}:8000 or :8080
- HTTP + Payload          : payload listener on ${domain}:700
- HTTP + Proxy + Payload  : proxy ${domain}:8000 then payload target 127.0.0.1:443
- SSL Direct              : ${domain}:111 or ${domain}:443
- SSL + Payload           : ${domain}:443 with payload target 127.0.0.1:443
- SSL + Proxy + Payload   : proxy ${domain}:8000 then TLS ${domain}:443 with payload target 127.0.0.1:443
- SSL + Proxy + Payload + SNI : same as above, with SNI ${domain}

OVPN
- Direct Connection > TCP : ${domain}:1194
- Direct Connection > UDP : ${domain}:110
- HTTP + Proxy            : proxy ${domain}:8000 to TCP 1194
- HTTP + Payload          : payload path can tunnel to OpenVPN TCP
- HTTP + Proxy + Payload  : proxy + payload path can tunnel to OpenVPN TCP
- SSL + Payload           : TLS payload path can tunnel to OpenVPN TCP
- SSL + Proxy + Payload   : proxy + TLS payload path can tunnel to OpenVPN TCP
- SSL + Proxy + Payload + SNI : same as above, with SNI ${domain}

Notes
- SSH keeps the main 443 multiplexer flow.
- OpenVPN direct TCP remains on 1194 for the cleanest direct client setup.
- OpenVPN payload-style modes still depend on app behavior and should be tested after install.
EOF
}

show_active_logins() {
    local found=0
    local username ssh_count ovpn_count xray_count xray_allowed xray_blocked xray_disabled total_count state_file block_file disabled_file status limit max_count freeze_file now xray_ttl

    now="$(date +%s)"
    xray_ttl="${XRAY_LOCK_TTL_SECONDS:-60}"

    printf "%-20s | %-5s | %-5s | %-5s | %-11s | %-12s\n" "Username" "SSH" "OVPN" "Xray" "Total Login" "Status"
    printf '%s\n' "---------------------+-------+-------+-------+-------------+--------------"

    while IFS= read -r username; do
        [ -n "$username" ] || continue
        found=1
        ssh_count="$(ps -eo user=,cmd= | awk -v user="$username" '$1 == user && $0 ~ /sshd-session/ { count++ } END { print count + 0 }')"
        ovpn_count="$(awk -F',' -v user="$username" '$1=="CLIENT_LIST" && $2==user { count++ } END { print count + 0 }' /etc/openvpn/tcp_stats.log /etc/openvpn/udp_stats.log 2>/dev/null)"
        state_file="${XRAY_IP_LOCK_DIR}/$(printf '%s' "$username" | tr -c 'A-Za-z0-9_.-' '_')"
        block_file="/etc/ErwanScript/xray-ip-block/$(printf '%s' "$username" | tr -c 'A-Za-z0-9_.-' '_')"
        disabled_file="${XRAY_DISABLED_DIR}/$(printf '%s' "$username" | tr -c 'A-Za-z0-9_.-' '_').json"
        xray_allowed=0
        xray_blocked=0
        xray_disabled=0
        if [ -f "$state_file" ]; then
            xray_allowed="$(awk -v now="$now" -v ttl="$xray_ttl" '$1 != "127.0.0.1" && $1 != "::1" && NF >= 2 && (now - $2) <= ttl { count++ } END { print count + 0 }' "$state_file")"
        fi
        if [ -f "$block_file" ]; then
            xray_blocked="$(awk -v now="$now" -v ttl="$xray_ttl" '$1 != "127.0.0.1" && $1 != "::1" && NF >= 2 && (now - $2) <= ttl { count++ } END { print count + 0 }' "$block_file")"
        fi
        if [ -f "$disabled_file" ] && command -v jq >/dev/null 2>&1; then
            xray_disabled="$(jq -r '.observed_slots // 0' "$disabled_file" 2>/dev/null)"
            if ! [[ "$xray_disabled" =~ ^[0-9]+$ ]]; then
                xray_disabled=0
            fi
        fi
        xray_count=$((xray_allowed + xray_blocked))
        if [ "$xray_disabled" -gt "$xray_count" ]; then
            xray_count="$xray_disabled"
        fi
        total_count=$((ssh_count + ovpn_count + xray_count))
        limit="$(awk -v key="$username" '$1 == key { print $2; exit }' "$MULTILOGIN_FILE" 2>/dev/null)"
        if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -le 0 ]; then
            limit="$(head -n 1 "$MULTILOGIN_DEFAULT_FILE" 2>/dev/null)"
        fi
        if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -le 0 ]; then
            limit=1
        fi
        freeze_file="${USER_LOCK_DIR}/freeze-${username}"
        max_count="$ssh_count"
        [ "$ovpn_count" -gt "$max_count" ] && max_count="$ovpn_count"
        [ "$xray_count" -gt "$max_count" ] && max_count="$xray_count"
        if [ -f "$freeze_file" ]; then
            status="FROZEN"
        elif [ -f "$disabled_file" ]; then
            status="FROZEN"
        elif [ "$xray_blocked" -gt 0 ] || [ "$xray_count" -gt "$limit" ]; then
            status="XRAY LIMITED"
        elif [ "$max_count" -gt "$limit" ]; then
            status="OVER LIMIT"
        else
            status="OK"
        fi
        printf "%-20s | %-5s | %-5s | %-5s | %-11s | %-12s\n" "$username" "$ssh_count" "$ovpn_count" "$xray_count" "$total_count" "$status"
    done < <(
        {
            list_panel_users
            awk 'NF { print $1 }' "$USER_EXPIRY_FILE" 2>/dev/null
            awk 'NF { print $1 }' "$XRAY_EXPIRY_FILE" 2>/dev/null
            awk 'NF { print $1 }' "$MULTILOGIN_FILE" 2>/dev/null
            list_xray_users
            ps -eo user=,cmd= | awk '/sshd-session/ && $1 != "root" { print $1 }'
            awk -F',' '$1=="CLIENT_LIST" && $2 != "" { print $2 }' /etc/openvpn/tcp_stats.log /etc/openvpn/udp_stats.log 2>/dev/null
            if [ -d "$XRAY_IP_LOCK_DIR" ]; then
                find "$XRAY_IP_LOCK_DIR" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r state_file; do
                    if awk -v now="$now" -v ttl="$xray_ttl" '$1 != "127.0.0.1" && $1 != "::1" && NF >= 2 && (now - $2) <= ttl { found=1 } END { exit(found ? 0 : 1) }' "$state_file"; then
                        basename "$state_file"
                    fi
                done
            fi
            if [ -d /etc/ErwanScript/xray-ip-block ]; then
                find /etc/ErwanScript/xray-ip-block -maxdepth 1 -type f 2>/dev/null | while IFS= read -r block_file; do
                    if awk -v now="$now" -v ttl="$xray_ttl" '$1 != "127.0.0.1" && $1 != "::1" && NF >= 2 && (now - $2) <= ttl { found=1 } END { exit(found ? 0 : 1) }' "$block_file"; then
                        basename "$block_file"
                    fi
                done
            fi
            if [ -d "$XRAY_DISABLED_DIR" ]; then
                find "$XRAY_DISABLED_DIR" -maxdepth 1 -type f -name '*.json' 2>/dev/null | while IFS= read -r disabled_file; do
                    basename "$disabled_file" .json
                done
            fi
        } | awk 'NF' | sort -u
    )

    if [ "$found" -eq 0 ]; then
        echo "No active logins found."
    fi
}

show_active_login_details() {
    echo "Current SSH Sessions"
    ps -eo user=,cmd= | awk '/sshd-session/ && $1 != "root" { print $1 " | " $0 }' | sort -u || true
    echo
    echo "Current OpenVPN Sessions"
    awk -F',' '$1=="CLIENT_LIST"{printf "%s | %s | %s | %s\n", $2, $3, $4, FILENAME}' /etc/openvpn/tcp_stats.log /etc/openvpn/udp_stats.log 2>/dev/null || true
    echo
    echo "Recent OpenVPN Activity"
    tail -n 20 /etc/openvpn/tcp.log 2>/dev/null || true
    echo
    echo "Recent OpenVPN UDP Activity"
    tail -n 20 /etc/openvpn/udp.log 2>/dev/null || true
    echo
    echo "Current Xray Slots"
    if [ -d "$XRAY_IP_LOCK_DIR" ]; then
        find "$XRAY_IP_LOCK_DIR" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r state_file; do
            local user
            user="$(basename "$state_file")"
            awk -v user="$user" 'NF >= 2 { printf "%s | %s | last_seen=%s\n", user, $1, $2 }' "$state_file"
        done
    fi
}

uninstall_newscript() {
    if ! confirm_prompt "Uninstall NewScript from this VPS?"; then
        echo "Cancelled."
        return
    fi
    if [ -x "${XRAY_DIR}/uninstall.sh" ]; then
        "${XRAY_DIR}/uninstall.sh"
    else
        echo "uninstall.sh is not installed."
    fi
}

show_menu() {
    local ssh_status ovpn_status xray_status hysteria_status sdns_status
    ssh_status="$(service_state_label erwanssh)"
    if systemctl is-active --quiet openvpn-server@tcp 2>/dev/null || systemctl is-active --quiet openvpn-server@udp 2>/dev/null; then
        ovpn_status="${C_GREEN}RUNNING${C_RESET}"
    else
        ovpn_status="${C_RED}OFFLINE${C_RESET}"
    fi
    xray_status="$(service_state_label xray)"
    hysteria_status="$(service_state_label udp)"
    if systemctl is-active --quiet ErwanDNSTT 2>/dev/null && systemctl is-active --quiet ErwanDNS 2>/dev/null; then
        sdns_status="${C_GREEN}RUNNING${C_RESET}"
    else
        sdns_status="${C_RED}OFFLINE${C_RESET}"
    fi

    animate_menu_intro
    clear
    menu_line "=============================================================="
    printf "%b%s%b\n" "$C_BOLD$C_BLUE" "                     ERWAN CONTROL PANEL" "$C_RESET"
    menu_line "=============================================================="
    printf " %-10s %-18b %-10s %-18b %-10s %-18b\n" \
        "SSH:" "$ssh_status" "OVPN:" "$ovpn_status" "XRAY:" "$xray_status"
    printf " %-10s %-18b %-10s %-18b\n" \
        "HYSTERIA:" "$hysteria_status" "SDNS:" "$sdns_status"
    menu_line "------------------------------------------------------------"
    printf "%b  1%b  Create User\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  2%b  Delete User(s)\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  3%b  Edit User\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  4%b  List Users\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  5%b  Reboot VPS\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  6%b  Change Password\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  7%b  Restart Services\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  8%b  Extend Expiration\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b  9%b  Change Multilogin\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 10%b  Change Hysteria Obfs\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 11%b  Change WS Response\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 12%b  Restart All Services\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 13%b  Show OVPN Links\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 14%b  Show Protocol Matrix\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 15%b  Show Active Logins\n" "$C_GREEN$C_BOLD" "$C_RESET"
    printf "%b 16%b  Uninstall NewScript\n" "$C_GREEN$C_BOLD" "$C_RESET"
    menu_line "------------------------------------------------------------"
    printf "%b  0%b  Exit\n" "$C_RED$C_BOLD" "$C_RESET"
    menu_line "============================================================"
}

while true; do
    show_menu
    read -r -p "Select an option: " option
    case "$option" in
        1) open_menu_screen "CREATE USER"; create_user; pause ;;
        2) open_menu_screen "DELETE USER(S)"; delete_user; pause ;;
        3) open_menu_screen "EDIT USER"; edit_user; pause ;;
        4) open_menu_screen "LIST USERS"; list_users; pause ;;
        5) echo "Rebooting..."; reboot ;;
        6) open_menu_screen "CHANGE PASSWORD"; change_password; pause ;;
        7) open_menu_screen "RESTART SERVICES"; restart_service_menu; pause ;;
        8) open_menu_screen "EXTEND EXPIRATION"; extend_expiration; pause ;;
        9) open_menu_screen "CHANGE MULTILOGIN"; change_multilogin; pause ;;
        10) open_menu_screen "CHANGE HYSTERIA OBFS"; change_hysteria_obfs; pause ;;
        11) open_menu_screen "CHANGE WS RESPONSE"; change_ws_response; pause ;;
        12) open_menu_screen "RESTART ALL SERVICES"; restart_all_services; pause ;;
        13) open_menu_screen "OVPN LINKS"; show_openvpn_links; pause ;;
        14) open_menu_screen "PROTOCOL MATRIX"; show_protocol_matrix; pause ;;
        15) open_menu_screen "ACTIVE LOGINS"; show_active_logins; pause ;;
        16) open_menu_screen "UNINSTALL NEWSCRIPT"; uninstall_newscript; exit 0 ;;
        0)
            clear
            if [ -r /etc/profile.d/erwan.sh ]; then
                # Reuse the same login banner instead of duplicating stale output here.
                . /etc/profile.d/erwan.sh >/dev/null 2>&1 || true
                if command -v show_erwan_banner >/dev/null 2>&1; then
                    show_erwan_banner
                else
                    /etc/profile.d/erwan.sh >/dev/null 2>&1 || true
                fi
            fi
            exit 0
            ;;
        *) echo "Invalid option. Press Enter to try again."; pause ;;
    esac
done
