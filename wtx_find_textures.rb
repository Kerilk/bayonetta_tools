#!ruby
require 'yaml'
require 'optparse'
require_relative 'lib/bayonetta'

class WTBFilePartial < LibBin::DataConverter
  uint32 :id
  uint32 :unknown
  uint32 :num_textures
  uint32 :offset_texture_offsets
  uint32 :offset_texture_sizes
  uint32 :offset_texture_flags
  uint32 :offset_texture_ids
  uint32 :offset_texture_infos
  uint32 :texture_ids, count: 'num_textures', offset: 'offset_texture_ids'
end

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

yaml_wtx_block = lambda{ |big, f|
  begin
    w = WTBFilePartial::load(f, big)
    w.texture_ids
  rescue
    []
  end
}

yaml_dat_block = lambda { |path|
  h = {}
  begin
    d = Bayonetta::DATFile::load(path)
    d.each.select { |name, f|
      [".wta", ".wtb"].include? File.extname(name)
    }.each { |name, f|
      res = yaml_wtx_block.call(d.big, f)
      h[name] = res if res.size > 0
    }
    h
  rescue
    h
  end
}

wtx_block = lambda { |big, file_path, f|
  begin
    w = WTBFilePartial::load(f, big)
    w.texture_ids.each { |id|
      puts "#{file_path}:#{"%08x" % id}"
    }
  rescue
    next
  end
}

dat_block = lambda { |path|
  begin
    d = Bayonetta::DATFile::load(path)
    path = path.gsub("/", "\\") if $options[:windows]
    d.each.select { |name, f|
      [".wta", ".wtb"].include? File.extname(name)
    }.each { |name, f|
      wtx_block.call(d.big, path + ":" + name, f)
    }
  rescue
    next
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
