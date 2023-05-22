require 'optparse'
require 'yaml'
require_relative '../../bayonetta'
include Bayonetta

$options = {
  output: nil
}
OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wtx_creator target_directory
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

files  = Dir.entries(input_dir)
pwd = Dir.pwd
Dir.chdir(input_dir)
files.select! { |f| File.file?(f) && [".gtx", ".dds", ".bntx", ".xt1"].include?( File.extname(f) ) }
files.sort!
puts files
files.collect! { |fname| File::new(fname, "rb") }

big = false
big = YAML::load_file(".metadata/big.yaml") if File.exist?(".metadata/big.yaml")
extension = ".wtb"
extension = YAML::load_file(".metadata/extension.yaml") if File.exist?(".metadata/extension.yaml")
flags = []
flags = YAML::load_file(".metadata/texture_flags.yaml") if File.exist?(".metadata/texture_flags.yaml")
idx = []
idx = YAML::load_file(".metadata/texture_idx.yaml") if File.exist?(".metadata/texture_idx.yaml")
infos = []
infos = YAML::load_file(".metadata/texture_infos.yaml") if File.exist?(".metadata/texture_infos.yaml")
unknown = 0
unknown = YAML::load_file(".metadata/unknown.yaml") if File.exist?(".metadata/unknown.yaml")


wtb = WTBFile::new(nil, big, extension == ".wta")
files.each { |f|
  wtb.push(f)
}
wtb.texture_flags = flags
wtb.texture_infos = infos
wtb.texture_idx   = idx
wtb.unknown       = unknown

output_file = $options[:output]
if !output_file
  Dir.mkdir("wtx_output") unless Dir.exist?("wtx_output")
  Dir.chdir("wtx_output")
  output_file = File.basename(ARGV[0]).gsub("_wta","").gsub("_wtb", "") << extension
else
  Dir.chdir(pwd)
end

wtb.dump(output_file)

