# Wuthering Waves Resource Downloader
A simple script to download and patch Wuthering Waves from command line

## Usage
Just execute the script in game's Root folder that contains `Wuthering Waves.exe` or any folder that you want to download the game into.

Before using, please edit the script and add `hpatchz.exe`'s path from the official launcher. Otherwise the script wouldn't be able to patch the game.


`indexUrl` is optional argument for custom well, index URL. Shouldn't change too frequently though

`./ww-launcher.sh [indexUrl]`

or

`./ww-launcher.sh`

## Dependencies
- `curl`
- `jq`
- `sed`
- `wine`