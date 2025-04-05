#!/usr/bin/env bash

LAUNCHER_INDEX="https://prod-alicdn-gamestarter.kurogame.com/launcher/game/G153/50004_obOHXFrFanqsaIEOmuKroCcbZkQRBC7c/index.json"
HPATCHZ_PATH=""
if [[ $1 ]]; then
    LAUNCHER_INDEX=$1
fi

launcherIndex=$(curl -fsSL --compressed $LAUNCHER_INDEX)
gameDir=$(pwd)
downloadDir=$gameDir/launcherDownload
[[ ! -d $downloadDir ]] && mkdir -p $downloadDir
# get main CDN
cdn=$(echo $launcherIndex | jq ".default | .cdnList[0] | .url" | sed 's/"//g')
defaultConfig="$(echo $launcherIndex | jq '.default')" # index.json | default
mainConfig=""                                          # defaultConfig | config
patchConfig=""                                         # mainConfig | patchConfig depending on version
resourceList=""                                        # resource.json or indexFile.json
downloadType=""

verifyGameFileHash() {
    echo "Verifying game file hashes"
    cat "$gameDir/gameResource.json" | jq -r '.resource[] | "\(.md5)  \(.dest)"' | md5sum -c
}

verifyPatchFileHash() {
    echo "Verifying patch file hashes"
    cd $downloadDir
    cat $patchConfig | jq -r '.resource[] | "\(.md5)  \(.dest)"' | md5sum -c
    cd $gameDir
}

fetchGameIndex() {
    local latestVersion=$(echo "$defaultConfig" | jq ".version")
    echo Latest Version: $latestVersion
    if [[ -f "$gameDir/launcherDownloadConfig.json" ]]; then
        echo Game exist. Starting patch download
        local currentVersion=$(cat $gameDir/launcherDownloadConfig.json | jq '.version')
        # echo Current Version: $currentVersion
        mainConfig=$(echo $launcherIndex | jq '.default | .config')
        # echo Main Config: $mainConfig
        if [[ $latestVersion != $currentVersion ]]; then
            downloadDir=$downloadDir/$(echo $latestVersion | sed 's/"//g')
            echo $downloadDir
            echo "Getting $latestVersion config"
            patchConfig=$(echo $mainConfig | jq ".patchConfig[] | select(.version == $currentVersion)")
            # echo $patchConfig
            local url=$cdn$(echo $patchConfig | jq '.indexFile' | sed 's/"//g')
            echo "Downloading config from $url"
            resourceList="$(curl -fsSL $url)"
            downloadType="patch"
        else
            downloadType="clear"
        fi
    else
        echo "Game does not exist. Starting download"
        mainConfig=$(echo $defaultConfig | jq ".config")
        local url=$cdn$(echo $mainConfig | jq '.indexFile' | sed 's/"//g')
        echo "Downloading config from $url"
        patchConfig="$(curl -fsSL $url)"
        downloadType="origin"
    fi
}

downloadFile() {
    curl -L --progress-bar -C - $1 --create-dirs -o $2
}

downloadGameFiles() {
    echo $1
    local basePath=$(echo $mainConfig | jq '.baseUrl' | sed 's/"//g')
    if [[ "$downloadType" = "origin" ]]; then
        # Download All Files
        echo Origin
        downloadDir=$(pwd)
        echo $patchConfig | jq -r >$downloadDir/gameResource.json
        echo $patchConfig | jq '.resource[] | "\(.dest) \(.md5)"' | while read resource; do
            IFS=' ' read -r -a array <<<"$resource"
            dest=$(echo ${array[0]} | sed 's/"//g')
            hash=$(echo ${array[1]} | sed 's/"//g')
            local url="$cdn$basePath$dest"
            echo Downloading "$dest" from $url
            downloadFile $url "$downloadDir/$dest"
        done
    elif [[ "$downloadType" = "patch" ]]; then
        # Download Patch
        echo Patch
        basePath=$(echo $patchConfig | jq '.baseUrl' | sed 's/"//g')
        echo $resourceList | jq '.resource[] | "\(.dest) \(.md5) \(.fromFolder)"' | while read resource; do
            IFS=' ' read -r -a array <<<"$resource"
            dest=$(echo ${array[0]} | sed 's/"//g')
            hash=$(echo ${array[1]} | sed 's/"//g')
            fromFolder=$(echo ${array[2]} | sed 's/"//g')
            if [[ "$fromFolder" != "null" ]]; then
                local url="$cdn$fromFolder$dest"
            else
                local url="$cdn$basePath$dest"
            fi
            echo Downloading $dest from $url
            downloadFile "$url" "$downloadDir/$dest"
        done

    elif [[ "$downloadType" = "clear" ]]; then
        # Up-to-date version. just leave
        echo Game is up-to-date
        exit 0
    else
        echo Undefined
    fi
}

startPatching() {
    echo "Patching game"
    local diffFile=$(find $downloadDir -name '*.krdiff')
    if [[ "$HPATCHZ_PATH" == "" && ! -f "$gameDir/hpatchz.exe" ]]; then
        echo hpatchz binary file path not found. Please set HPATCHZ_PATH or put the binary in the same folder as this script
    fi
    if [[ -f "$gameDir/hpatchz.exe" ]]; then
        HPATCHZ_PATH="$gameDir/hpatchz.exe"
    fi
    WINEDEBUG=-all wine $HPATCHZ_PATH $gameDir $diffFile $gameDir -f -s16M
    if [[ "$?" != "0" ]]; then
        echo "Failed to patch game"
        exit 1
    fi
    find $downloadDir -mindepth 1 -maxdepth 1 -not -name '*.krdiff' | xargs -o mv -t $gameDir
}

main() {
    fetchGameIndex
    downloadGameFiles
    verifyPatchFileHash
    verifyGameFileHash
}

main
