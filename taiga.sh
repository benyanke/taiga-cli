#!/bin/bash

set -e
set -u

if [ ! -f ~/.taigarc ]; then
    echo "No ~/.taigarc, will create one now"
    read -p "Username or email: " USERNAME
    read -r -s -p "Password: " PASSWORD
    echo 

    DATA=$(jq --null-input \
        --arg username "$USERNAME" \
        --arg password "$PASSWORD" \
        '{ type: "normal", username: $username, password: $password }')

    USER_AUTH_DETAIL=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$DATA" https://api.taiga.io/api/v1/auth 2> /dev/null)

    AUTH_TOKEN=$(echo ${USER_AUTH_DETAIL} | jq -r '.auth_token' )
    USER_ID=$(echo ${USER_AUTH_DETAIL} | jq -r '.id' )

    # Exit if AUTH_TOKEN is not available
    if [ -z ${AUTH_TOKEN} -o "${AUTH_TOKEN}" = "null" ]; then
        echo "Login failed, got response:"
        echo $USER_AUTH_DETAIL
        exit 1
    else
        echo "Login successful, creating ~/.taigarc"
        echo "AUTH_TOKEN=${AUTH_TOKEN}" >> ~/.taigarc
        echo "USER_ID=${USER_ID}" >> ~/.taigarc
    fi
fi

get_from_api() {
    local url="$1"
    curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        "https://api.taiga.io/api/v1/$url"
}

. ~/.taigarc

print_common_item() {
    local item="$1"
    local subject=$(echo "$item" | jq --raw-output '.subject')
    local tags=$(echo "$item" | jq --raw-output '.tags | join(", ")')
    echo "$subject [$tags]"
}

print_common_list() {
    local items="$1"
    local n=$(echo "$items" | jq --raw-output '. | length')

    for i in $(seq 0 $(($n - 1))); do
        local item=$(echo "$items" | jq --arg i $i '.[$i | tonumber]')
        print_common_item "$item"
    done
}

user_stories() {
    echo "User stories:"
    print_common_list "$(get_from_api "userstories?assigned_to=${USER_ID}&is_closed=false")"
    echo
}

tasks() {
    echo "Tasks:"
    print_common_list "$(get_from_api "tasks?assigned_to=${USER_ID}&status__is_closed=false")"
    echo
}

issues() {
    echo "Issues:"
    print_common_list "$(get_from_api "issues?assigned_to=${USER_ID}&status__is_closed=false")"
    echo
}


user_stories
tasks
issues
