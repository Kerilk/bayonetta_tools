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

  opts.on("-y", "--[no-]yaml", "Ouput YAML database") do |yaml|
    $options[:yaml] = yaml
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

yaml_dat_block = lambda { |path, fh=nil|
  h = []
  begin
    d = Bayonetta::DATFile::load(fh ? fh : path)
    d.each.select { |name, f|
      File.extname(name) == ".dat" || File.extname(name) == ".dtt"
    }.collect { |name, f|
      res = yaml_dat_block.call("", f)
      h.push = [name, res] if res.size > 0
    }
    d.each { |name, _|
      h.push name
    }
    h
  rescue
    h
  end
}

dat_block = lambda { |path, fh=nil|
  begin
    d = Bayonetta::DATFile::load(fh ? fh : path)
    path = path.gsub("/", "\\") if $options[:windows]
    d.each.select { |name, f|
      File.extname(name) == ".dat" || File.extname(name) == ".dtt"
    }.each { |name, f|
      dat_block.call(path + ":" + name, f)
    }
    d.each  { |name, _|
      puts "#{path}:#{name}"
    }
  rescue
    next
  end
}

path = ARGV[0]
h = []
if File::directory?(path)
  Dir.chdir(path)
  dats = Dir.glob("./**/*.d[at]t")
  dats.each { |path|
    if $options[:yaml]
      res = yaml_dat_block.call(path)
      path = path.gsub(ARGV[0],"")
      path = path.gsub("/", "\\") if $options[:windows]
      h.push [path, res] if res.size > 0
    else
      dat_block.call(path)
    end
  }
elsif File::exist?(path)
  if $options[:yaml]
    res = yaml_dat_block.call(path)
    path = path.gsub("/", "\\") if $options[:windows]
    h.push [path, res] if res.size > 0
  else
    dat_block.call(path)
  end
else
  raise "Invalid file or directory: #{ARGV[0]}!"
end

puts YAML::dump(h) if $options[:yaml]
