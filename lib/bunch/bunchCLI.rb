# frozen_string_literal: true

# Main Bunch CLI Class
class Bunch
  include Util
  attr_writer :url_method, :fragment, :variables, :show_url

  def initialize
    @bunch_dir = nil
    @url_method = nil
    @bunches = nil
    @fragment = nil
    @variables = nil
    @success = nil
    @show_url = false
    get_cache
  end

  def launch_if_needed
    pid = `ps ax | grep 'MacOS/Bunch'|grep -v grep`.strip
    return unless pid == ''

    `open -a Bunch`
    sleep 2
  end

  def update_cache
    @bunch_dir = nil
    @url_method = nil
    @bunches = nil
    target = File.expand_path(CACHE_FILE)
    settings = {
      'bunchDir' => bunch_dir,
      'method' => url_method,
      'bunches' => bunches,
      'updated' => Time.now.strftime('%s').to_i
    }
    File.open(target, 'w') do |f|
      f.puts YAML.dump(settings)
    end

    settings
  end

  def get_cache
    target = File.expand_path(CACHE_FILE)
    if File.exist?(target)
      settings = YAML.load(IO.read(target))
      now = Time.now.strftime('%s').to_i
      settings = update_cache if now - settings['updated'].to_i > CACHE_TIME
    else
      settings = update_cache
    end
    @bunch_dir = settings['bunchDir'] || bunch_dir
    @url_method = settings['method'] || url_method
    @bunches = settings['bunches'] || generate_bunch_list
  end

  def variable_query
    vars = @variables.split(/,/).map(&:strip)
    query = []
    vars.each do |v|
      parts = v.split(/=/).map(&:strip)
      k = parts[0]
      v = parts[1]
      query << "#{k}=#{CGI.escape(v)}"
    end
    query
  end

  # items.push({title: 0})
  def generate_bunch_list
    items = []
    `osascript -e 'tell app "#{TARGET_APP}" to list bunches'`.strip.split(/,/).each do |b|
      b.strip!
      items.push(
        path: File.join(bunch_dir, "#{b}.bunch"),
        title: b
      )
    end
    items.sort_by { |b| b[:title].downcase }
  end

  def bunch_dir
    @bunch_dir ||= begin
      dir = `osascript -e 'tell app "#{TARGET_APP}" to get preference "Folder"'`.strip
      # dir = `/usr/bin/defaults read #{ENV['HOME']}/Library/Preferences/com.brettterpstra.Bunch.plist configDir`.strip
      File.expand_path(dir)
    end
  end

  def url_method
    @url_method ||= `osascript -e 'tell app "#{TARGET_APP}" to get preference "Toggle"'`.strip == '1' ? 'toggle' : 'open'
    # @url_method ||= `/usr/bin/defaults read #{ENV['HOME']}/Library/Preferences/com.brettterpstra.Bunch.plist toggleBunches`.strip == '1' ? 'toggle' : 'open'
  end

  def bunches
    @bunches ||= generate_bunch_list
  end

  def url(bunch)
    bunch = CGI.escape(bunch).gsub(/\+/, '%20')
    params = "&x-success=#{@success}" if @success
    case url_method
    when /file/
      %(#{TARGET_URL}://raw?file=#{bunch}#{params})
    when /raw/
      %(#{TARGET_URL}://raw?txt=#{bunch}#{params})
    when /snippet/
      %(#{TARGET_URL}://snippet?file=#{bunch}#{params})
    when /setPref/
      %(#{TARGET_URL}://setPref?#{bunch})
    else
      %(#{TARGET_URL}://#{url_method}?bunch=#{bunch}#{params})
    end
  end

  def bunch_list
    list = []
    bunches.each { |bunch| list.push(bunch[:title]) }
    list
  end

  def list_bunches
    $stdout.puts bunch_list.join("\n")
  end

  def find_bunch(str)
    matches = []

    bunches.each { |bunch| matches.push(bunch) if bunch[:title].downcase =~ /.*?#{str}.*?/i }
    matches.min_by(&:length)
  end

  def human_action
    "#{url_method.gsub(/e$/, '')}ing".capitalize
  end

  def list_preferences
    puts <<~EOHELP
      toggleBunches=[0,1]        Allow Bunches to be both opened and closed
      configDir=[path]           Absolute path to Bunches folder
      singleBunchMode=[0,1]      Close open Bunch when opening new one
      preserveOpenBunches=[0,1]  Restore Open Bunches on Launch
      debugLevel=[0-4]           Set the logging level for the Bunch Log
    EOHELP
  end


  def open(str)
    launch_if_needed
    # get front app
    front_app = %x{osascript -e 'tell application "System Events" to return name of first application process whose frontmost is true'}.strip
    bid = bundle_id(front_app) || false
    @success = bid if bid

    case @url_method
    when /raw/
      warn 'Running raw string'
      if @show_url
        $stdout.puts url(str)
      else
        `open '#{url(str)}'`
      end
    when /snippet/
      this_url = url(str)
      params = []
      params << "fragment=#{CGI.escape(@fragment)}" if @fragment
      params.concat(variable_query) if @variables
      this_url += "&#{params.join('&')}" if params.length.positive?
      if @show_url
        $stdout.puts this_url
      else
        warn 'Opening snippet'
        `open '#{this_url}'`
      end
    when /setPref/
      if str =~ /^(\w+)=([^= ]+)$/
        this_url = url(str)
        if @show_url
          $stdout.puts this_url
        else
          warn "Setting preference #{str}"
          `open '#{this_url}'`
        end
      else
        warn 'Invalid key=value pair'
        Process.exit 1
      end
    else
      bunch = find_bunch(str)
      params = []
      params << "fragment=#{CGI.escape(@fragment)}" if @fragment
      params.concat(variable_query) if @variables
      if bunch
        this_url = url(bunch[:title])
        this_url += "&#{params.join('&')}" if params.length
        if @show_url
          $stdout.puts this_url
        else
          warn "#{human_action} #{bunch[:title]}"
          `open '#{this_url}'`
        end
      elsif File.exist?(str)
        @url_method = 'file'
        this_url = url(str)
        this_url += "&#{params.join('&')}" if params.length
        if @show_url
          $stdout.puts this_url
        else
          warn 'Opening file'
          `open '#{this_url}'`
        end
      else
        warn 'No matching Bunch found'
        Process.exit 1
      end
    end
    # attempt to restore front app
    # %x{osascript -e 'delay 2' -e 'tell application "#{front_app}" to activate'}
  end

  def show(str)
    bunch = find_bunch(str)
    output = `cat "#{bunch[:path]}"`.strip
    puts output
  end

  def show_config(key = nil)
    case key
    when /(folder|dir)/
      puts bunch_dir
    when /toggle/
      puts url_method == 'toggle' ? 'true' : 'false'
    when /method/
      puts url_method
    else
      puts "Bunches Folder: #{bunch_dir}"
      puts "Default URL Method: #{url_method}"
      puts 'Cached Bunches'
      bunches.each { |b| puts "    - #{b[:title]}" }
    end
  end
end
