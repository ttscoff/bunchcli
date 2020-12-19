class Bunch
  attr_writer :url_method

  def initialize
    @bunch_dir = nil
    @url_method = nil
    @bunches = nil
    get_cache
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
    File.open(target,'w') do |f|
      f.puts YAML.dump(settings)
    end
    return settings
  end

  def get_cache
    target = File.expand_path(CACHE_FILE)
    if File.exists?(target)
      settings = YAML.load(IO.read(target))
      now = Time.now.strftime('%s').to_i
      if now - settings['updated'].to_i > CACHE_TIME
        settings = update_cache
      end
    else
      settings = update_cache
    end
    @bunch_dir = settings['bunchDir'] || bunch_dir
    @url_method = settings['method'] || url_method
    @bunches = settings['bunches'] || generate_bunch_list
  end

  # items.push({title: 0})
  def generate_bunch_list
    items = []
    Dir.glob(File.join(bunch_dir, '*.bunch')).each do |f|
      items.push(
        path: f,
        title: File.basename(f, '.bunch')
      )
    end
    items
  end

  def bunch_dir
    @bunch_dir ||= begin
      dir = `/usr/bin/defaults read #{ENV['HOME']}/Library/Preferences/com.brettterpstra.Bunch.plist configDir`.strip
      File.expand_path(dir)
    end
  end

  def url_method
    @url_method ||= `/usr/bin/defaults read #{ENV['HOME']}/Library/Preferences/com.brettterpstra.Bunch.plist toggleBunches`.strip == '1' ? 'toggle' : 'open'
  end

  def bunches
    @bunches ||= generate_bunch_list
  end

  def url(bunch)
    if url_method == 'file'
      %(x-bunch://raw?file=#{bunch})
    elsif url_method == 'raw'
      %(x-bunch://raw?txt=#{bunch})
    else
      %(x-bunch://#{url_method}?bunch=#{bunch[:title]})
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
    found_bunch = false

    bunches.each do |bunch|
      if bunch[:title].downcase =~ /.*?#{str}.*?/i
        found_bunch = bunch
        break
      end
    end
    found_bunch
  end

  def human_action
    (url_method.gsub(/e$/, '') + 'ing').capitalize
  end

  def open(str)
    # get front app
    front_app = %x{osascript -e 'tell application "System Events" to return name of first application process whose frontmost is true'}.strip
    if @url_method == 'raw'
      warn 'Running raw string'
      `open '#{url(str)}'`
    else
      bunch = find_bunch(str)
      unless bunch
        if File.exists?(str)
          @url_method = 'file'
          warn "Opening file"
          `open '#{url(str)}'`
        else
          warn 'No matching Bunch found'
          Process.exit 1
        end
      else
        warn "#{human_action} #{bunch[:title]}"

        `open "#{url(bunch)}"`
      end
    end
    # attempt to restore front app
    %x{osascript -e 'delay 2' -e 'tell application "#{front_app}" to activate'}
  end

  def show(str)
    bunch = find_bunch(str)
    output = `cat "#{bunch[:path]}"`.strip
    puts output
  end

  def show_config
    puts "Bunches Folder: #{bunch_dir}"
    puts "Default URL Method: #{url_method}"
    puts "Cached Bunches"
    bunches.each {|b|
      puts "    - #{b[:title]}"
    }
  end
end
