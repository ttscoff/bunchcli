CACHE_TIME = 86400 #seconds, 1 day = 86400
CACHE_FILE = "~/.bunch_cli_cache"
TARGET_APP = "Bunch"

TARGET_URL = TARGET_APP == 'Bunch Beta' ? 'x-bunch-beta' : 'x-bunch'

require "bunch/version"
require 'yaml'
require 'cgi'
require 'bunch/url_generator'
require 'bunch/bunchCLI'
