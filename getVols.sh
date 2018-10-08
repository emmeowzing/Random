#! /bin/bash
# Print information about snapshots in /home/agents/*/.zfs/snapshot/, such as 
# included volumes, etc. This script is useful/unique because it allows us to
# compare information that was included with each snapshot as a list in the
# terminal.
#
# Syntax verified with shellcheck v0.5.0
# https://github.com/koalaman/shellcheck
#
# Brandon Doyle, October 7, 2018


##
# Collect UUID from the user that we wish to collect volinfo about.
getUUID()
{
    # Is this sustainable?
    #local agents="$(snapctl list 2>&1)"

    # Let's create our own that respects column widths.
    for agent in /home/agents/*
    do
        id="${agent##*/}"
        # Redirect to stderr so we can pipe this whole script to `column` 
        # independently.
        printf "%s,%s\\n" "$id" "$(grep -oP \
            "\"hostName\";s:[0-9]+:\"\\K[^\"]+" \
            "/datto/config/keys/$id.agentInfo")"
    done | column -s ',' -t 1>&2

    local agents="$(find /home/agents/ -maxdepth 1 -mindepth 1 -type d \
        | wc -l)"

    if [ "$agents" -eq 0 ]
    then
        printf "No agents found" 1>&2
        exit 1
    fi

    # Get user input, now that we've provided them with their options.
    local UUID

    while true
    do
        read -r -p "Enter UUID: " UUID

        # Ensure this is a valid identifier
        if ! [ -d "/home/agents/$UUID" ]
        then
            printf "ERROR: \"%s\" doesn't exist\\n" "$UUID" 1>&2
            continue
        else
            break
        fi
    done

    getSnapshots "$UUID"
}


##
# Loop over the UUID's snapshots (if they exist) and print volinfo.
getSnapshots()
{
    if [ "$#" -ne  1 ]
    then
        printf "getSnapshots() requires 1 argument, received %d\\n" "$#" 1>&2
        exit 1
    fi

    local UUID="$1"

    # Ensure it's a valid id (again, for safety)
    if ! [ -d "/home/agents/$UUID" ]
    then
        printf "ERROR: \"%s\" doesn't exist\\n" "$UUID" 1>&2
        exit 1
    fi

    # Loop over this agent's snapshots and list included directories.
    for epoch in /home/agents/"$UUID"/.zfs/snapshot/*
    do 
        timestamp="$(echo "$epoch" | grep -oP "[0-9]+$")" 

        if [ "$timestamp" ]
        then
            convertedDate="$(date -d@"$timestamp")"
            printf "%s: " "$convertedDate"
            volt="$epoch/voltab"

            if [ -e "$volt" ]
            then 
                match="$(grep -oP "(?<=(\"mountpoint\":\"))[A-Z]" "$volt" \
                    | awk '{ printf "%s:\\ ",$0,NR % 7 ? " " : "\n"; }')"

                if ! [ "$match" ]
                then 
                    printf "* No volumes included in voltab\\n"
                else 
                    printf "%s\\n" "$match"
                fi
            else 
                printf "voltab doesn't exist\\n"
            fi
        else
            printf "No snapshots\\n"
        fi
    done
}


getUUID
exit 0
