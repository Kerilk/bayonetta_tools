require 'optparse'
require 'yaml'
require_relative '../../bayonetta'

$options = {
  output: nil
}
OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: eff_idd_creator target_directory
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
pwd_basedir = Dir.pwd

id = YAML::load_file(".metadata/id.yaml")
big = YAML::load_file(".metadata/big.yaml")
extension = YAML::load_file(".metadata/extension.yaml")
suffix = extension.gsub(".", "_")

file_name = File.basename(input_dir).gsub(suffix, "")

eff = Bayonetta::EFFFile::new(nil, big, id)

eff.layout = YAML::load_file(".metadata/layout.yaml")

eff.layout.each { |id, dname|
  d = Bayonetta::EFFFile::Directory::new(nil, big)
  d.name = dname
  fnames = Dir.entries("#{dname}")
  Dir.chdir(dname)
  fnames.select! { |f| File.file?(f) }
  fnames.sort!
  fnames.each { |fname|
    d.push( File::basename(fname, File::extname(fname)).to_i, File::new(fname, "rb"))
  }
  eff.push(id, d)
  Dir.chdir(pwd_basedir)
}

output_file = $options[:output]
if !output_file
  Dir.mkdir("eff_output") unless Dir.exist?("eff_output")
  Dir.chdir("eff_output")
  output_file = file_name+extension
else
  Dir.chdir(pwd)
end
File::open(output_file, "wb") { |f|
  f.write eff.to_stringio.read
}
