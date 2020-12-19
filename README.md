# Bunch

A CLI for [Bunch.app](https://brettterpstra.com/projects/bunch).

## Installation

    $ gem install bunch

## Usage

    $ bunch -h  
    CLI for Bunch.app
    -h, --help                       Display this screen
    -f, --force-refresh              Force refresh cached preferences
    -l, --list                       List available Bunches
    -o, --open                       Open Bunch ignoring "Toggle Bunches" preference
    -c, --close                      Close Bunch ignoring "Toggle Bunches" preference
    -t, --toggle                     Toggle Bunch ignoring "Toggle Bunches" preference
    -s, --show BUNCH                 Show contents of Bunch
        --show-config                Display configuration values

Usage: `bunch [options] BUNCH_NAME|PATH_TO_FILE`

Bunch names are case insensitive and will execute first match

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
