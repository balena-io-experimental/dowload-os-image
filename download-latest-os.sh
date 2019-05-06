#!/bin/bash

set -x

SLUG=$1
SLUG=${SLUG:-fin-cm3}

API="api.balena-cloud.com"
S3="files.resin.io"

uriencode() {
    # URL Encoding of strings
    s="${1//'%'/%25}"
    s="${s//' '/%20}"
    s="${s//'"'/%22}"
    s="${s//'#'/%23}"
    s="${s//'$'/%24}"
    s="${s//'&'/%26}"
    s="${s//'+'/%2B}"
    s="${s//','/%2C}"
    s="${s//'/'/%2F}"
    s="${s//':'/%3A}"
    s="${s//';'/%3B}"
    s="${s//'='/%3D}"
    s="${s//'?'/%3F}"
    s="${s//'@'/%40}"
    s="${s//'['/%5B}"
    s="${s//']'/%5D}"
    printf %s "$s"
}

main() {
    local latest_version
    local latest_version_encoded
    local download_link
    local local_size
    local remote_size

    latest_version=$(curl --retry 10 --silent --fail https://${API}/config | jq -r '.deviceTypes[] | select(.slug=="'"${SLUG}"'") | .buildId')
    if [ -z "${latest_version}" ]; then
        echo "Could not find latest OS version for device type $SLUG"
    else
        echo "Latest balenaOS for $SLUG is $latest_version"
        latest_version_encoded=$(uriencode "${latest_version}")
        if [ -f "balena.img.zip" ]; then
            local_size=$(wc -c < balena.img.zip)
        else
            local_size=0
        fi

        # Check remote file size
        download_link="https://${S3}/resinos/${SLUG}/${latest_version_encoded}/image/balena.img.zip"
        remote_size=$(curl --retry 10 -sIL "${download_link}" | awk '/Content-Length/ {sub("\r",""); print $2}')
        if [ $? -eq 22 ]; then
            download_link="https://${S3}/resinos/${SLUG}/${latest_version_encoded}/image/resin.img.zip"
            remote_size=$(curl --retry 10 -sIL "${download_link}" | awk '/Content-Length/ {sub("\r",""); print $2}')
            if [ $? -eq 22 ]; then
                echo "Image file not found..."
                exit 1
            fi
        fi
        # Only download if remote and local file size differs
        if [ "${local_size}" -ne "${remote_size}" ]; then
            if curl --retry 10 --fail --silent -L "${download_link}" -o "balena.img.zip" ; then
                echo "Image file downloaded..."
            else
                echo "Image file couldn't be downloaded..."
                exit 2
            fi
        else
            echo "Image already downloaded..."
        fi
    fi
}

main