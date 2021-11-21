require 'optparse'
require 'yaml'
require_relative '../../bayonetta'

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: scr_extractor file
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--output=dirname", "directory to output result") do |name|
    $options[:output] = name
  end

end.parse!

save_pwd = Dir.pwd

raise "Invalid output directory #{$options[:output]}" if $options[:output] && !Dir.exist?($options[:output])

filename = ARGV[0]
raise "Invalid file: #{filename}!" unless filename && File.exist?(filename)
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)

raise "Invalid file: #{filename}!" unless ext_name == ".scr"

f = File::open(filename, "rb")

if $options[:output]
  Dir.chdir(save_pwd)
  Dir.chdir($options[:output])
else
  Dir.chdir(directory)
end
dir_name = File.basename(name, ext_name) + "#{ext_name.gsub(".","_")}"
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

scr = Bayonetta::SCRFile::load(f)

scr.each_model.each_with_index { |f1, i|
  File::open("%03d.wmb" % [i] , "wb") { |f2|
    f1.rewind
    f2.write(f1.read)
  }
}

f1 = scr.textures
if f1
  File::open("000.wtb", "wb") { |f2|
    f1.rewind
    f2.write(f1.read)
  }
end

Dir.mkdir(".metadata") unless Dir.exist?(".metadata")
Dir.chdir(".metadata")
File::open("models_metadata.yaml", "w") { |fl|
  fl.print YAML::dump( scr.models_metadata )
}
File::open("big.yaml","w") { |fl|
  fl.print YAML::dump( scr.big )
}
File::open("bayo2.yaml","w") { |fl|
  fl.print YAML::dump( scr.bayo2? )
}
File::open("unknown.yaml", "w") { |fl|
  fl.print YAML::dump( scr.unknown )
}
