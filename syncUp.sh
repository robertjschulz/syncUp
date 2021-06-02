#!/bin/sh


# syncUp is a shell program syncing a local folder to a target server and keep the target up to date quickly.
# This normally is helpful for developing and Dev-Testing on a remote machine.
# 
#    Copyright (C) 2021 Robert Jürgen Schulz
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

function usage () {
    echo 'usage: syncUp <local folder> <remote url>'
    echo 'usage: syncUp <remote url>'
    echo '  sample: syncUp . user@myhost.org:/var/httpd/'
    echo '  local folder default is "." '
    echo ''
    echo 'syncUp is using rsync, ssh and the fswatch command to sync a local folder to a remote url and then watch the local folder and push updates immediately'
    echo '(c) Robert Schulz, '
    
}

me="$0"

if [ "$2" ] ; then
    localBasePath="$1"
    remoteBasePath="$2"
elif [ "$1" ] ; then
    localBasePath="."
    remoteBasePath="$1"
else
    usage
    exit 1
fi

echo localBasePath=$localBasePath
echo remoteBasePath=$remoteBasePath

function uploadFile () {
    local RSYNC_EXIT_SIGINT=20
    local src="$1"
    local srcrel="${src#$localBasePath}"
    local dst="${remoteBasePath}${srcrel}"
    echo srcrel=$srcrel
    local RSYNC_OPTS="-P --delay-updates --partial"
    if type rsync; then
        until rsync $RSYNC_OPTS --rsync-path="mkdir -p \"${remoteBasePath}\" && rsync" "$src" ninawebps@gh-srvninaweb01.nuance.com:"$dst" ; do 
            local rc=$?
            if [[ $rc == $RSYNC_EXIT_SIGINT ]]; then
                echo "INTERRIUPTED... ($rc) stopping...";
                exit 20
            else
                echo "FAILED... ($?) retrying"; 
            fi
        done
    else
        scp "$src" ninawebps@ui-dev.nina-nuance.com:"$dst" || { echo FAILED; exit 1; }
    fi
}

export -f uploadFile

RSYNC_OPTS="-P --delay-updates --partial"

for f in "${localBasePath}"/* ; do
  uploadFile "$f" 
done

fswatch -0 \
  "${localBasePath}"/* \
  | while IFS= read -r -d '' ; do echo "$REPLY" ; uploadFile "$REPLY" ; done

# xargs -0 -n1 -I '{}' rsync $RSYNC_OPTS '{}' ninawebps@ui-dev.nina-nuance.com:"$uidevname"'{}'
