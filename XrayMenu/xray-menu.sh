#!/bin/bash

while true; do
    clear
    cat <<'EOF'
==============================
        Erwan Xray Menu
==============================
1. Add Xray User
2. Remove Xray User
3. List Xray Users
4. Show Xray Expiry
5. Reset Xray Users
6. Cleanup Expired Xray Users
7. Restart Xray
0. Back
EOF
    read -r -p "Select an option: " option

    case $option in
        1)
            /etc/ErwanScript/XrayMenu/add-xray-user.sh
            read -r -p "Press Enter to continue..." _
            ;;
        2)
            /etc/ErwanScript/XrayMenu/remove-xray-user.sh
            read -r -p "Press Enter to continue..." _
            ;;
        3)
            /etc/ErwanScript/XrayMenu/list-xray-users.sh
            read -r -p "Press Enter to continue..." _
            ;;
        4)
            /etc/ErwanScript/XrayMenu/show-xray-expiry.sh
            read -r -p "Press Enter to continue..." _
            ;;
        5)
            read -r -p "Reset all Xray users? [y/N]: " answer
            if [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                /etc/ErwanScript/XrayMenu/reset-xray-users.sh
            else
                echo "Cancelled."
            fi
            read -r -p "Press Enter to continue..." _
            ;;
        6)
            /etc/ErwanScript/XrayMenu/cleanup-expired.sh
            read -r -p "Press Enter to continue..." _
            ;;
        7)
            systemctl restart xray
            echo "Xray restarted."
            read -r -p "Press Enter to continue..." _
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option"
            read -r -p "Press Enter to continue..." _
            ;;
    esac
done
