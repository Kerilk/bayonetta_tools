require 'optparse'
require 'yaml'
require_relative '../../bayonetta'

$options = {
  output: nil
}
OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: dat_creator target_directory
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--output=filename", "file to output result") do |name|
    $options[:output] = name
  end

end.parse!


input_dir = ARGV[0]

raise "Not a directory: #{input_dir}!" unless input_dir && File.directory?(input_dir)

pwd = Dir.pwd
Dir.chdir(input_dir)
Dir.mkdir("dat_output") unless $options[:output] || Dir.exist?("dat_output")

big = YAML::load_file(".metadata/big.yaml")

d = Bayonetta::DATFile::new(big)

layout = YAML::load_file(".metadata/layout.yaml")

layout.each { |fname|
  File::open(fname, "rb") { |f|
    d.push(fname, StringIO.new(f.read,"rb") )
  }
}

if File::exist?(".metadata/hash_map.yaml")
  d.set_hash_map YAML::load_file(".metadata/hash_map.yaml")
end

output_file = $options[:output]
if !output_file
  extension = YAML::load_file(".metadata/extension.yaml")
  suffix = extension.gsub(".", "_")
  output_file = "dat_output/#{File.basename(input_dir).gsub(suffix, "")}#{extension}"
else
  Dir.chdir(pwd)
end

d.dump(output_file)
