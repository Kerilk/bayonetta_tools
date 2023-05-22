require 'optparse'
require 'yaml'
require_relative '../../bayonetta'

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: eff_idd_extractor file
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

raise "Invalid file: #{filename}!" unless ext_name == ".eff" || ext_name == ".idd"

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

eff = Bayonetta::EFFFile::new(f)

eff.each_directory { |id, dir|
  Dir.mkdir(dir.name) unless Dir.exist?(dir.name)
  dir.each { |fname, f2|
    File::open("#{dir.name}/#{fname}", "wb") { |f3|
      f2.rewind
      f3.write(f2.read)
    }
  }
}

Dir.mkdir(".metadata") unless Dir.exist?(".metadata")
Dir.chdir(".metadata")
File::open("id.yaml", "w") { |fl|
  fl.print YAML::dump( eff.id )
}
File::open("layout.yaml", "w") { |fl|
  fl.print YAML::dump( eff.layout )
}
File::open("extension.yaml", "w") { |fl|
  fl.print YAML::dump( ext_name )
}
File::open("big.yaml","w") { |fl|
  fl.print YAML::dump( eff.big )
}
