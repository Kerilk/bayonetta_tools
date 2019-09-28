#!ruby
require 'yaml'
require 'optparse'
require_relative 'lib/bayonetta'

$options = {
  windows: false,
  yaml: false
}

OptionParser.new do |opts|

  opts.on("-w", "--[no-]windows", "Output Windows path") do |windows|
    $options[:windows] = windows
  end

  opts.on("y", "--[no-]yaml", "Ouput YAML database") do |yaml|
    $options[:yaml] = yaml
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

yaml_wmb_block = lambda{ |big, f|
  begin
    w = Bayonetta::WMBFile::load(f)
    w.materials_textures
  rescue
    {}
  end
}

yaml_dat_block = lambda { |path|
  h = {}
  begin
    d = Bayonetta::DATFile::load(path)
    d.each.select { |name, f|
      [".wmb"].include? File.extname(name)
    }.each { |name, f|
      res = yaml_wmb_block.call(d.big, f)
      h[name] = res if res.size > 0
    }
    h
  rescue
    h
  end
}

wmb_block = lambda { |big, file_path, f|
  begin
    w = Bayonetta::WMBFile::load(f)
    if w.kind_of?(Bayonetta::WMBFile)
      w.materials_textures.each { |indx, ids|
        ids.each { |id|
          puts "#{file_path}:#{indx}:#{"%08x" % id}"
        }
      }
    else
      w.materials_textures.each { |matname, ids|
        matname = matname.gsub("\x00","")
        ids.each { |id, name|
          puts "#{file_path}:#{matname}:#{"%08x" % id}:#{name.gsub("\x00","")}"
        }
      }
    end
  end
}

dat_block = lambda { |path|
  begin
    d = Bayonetta::DATFile::load(path)
    path = path.gsub("/", "\\") if $options[:windows]
    d.each.select { |name, f|
      [".wmb"].include? File.extname(name)
    }.each { |name, f|
      wmb_block.call(d.big, path + ":" + name, f)
    }
  end
}

path = ARGV[0]
h = {}
if File::directory?(path)
  Dir.chdir(path)
  dats = Dir.glob("./**/*.dat")
  dats.each { |path|
    if $options[:yaml]
      res = yaml_dat_block.call(path)
      path = path.gsub(ARGV[0],"")
      path = path.gsub("/", "\\") if $options[:windows]
      h[path] = res if res.size > 0
    else
      dat_block.call(path)
    end
  }
elsif File::exist?(path)
  if $options[:yaml]
    res = yaml_dat_block.call(path)
    path = path.gsub("/", "\\") if $options[:windows]
    h[path] = res if res.size > 0
  else
    dat_block.call(path)
  end
else
  raise "Invalid file or directory: #{ARGV[0]}!"
end

puts YAML::dump(h) if $options[:yaml]
