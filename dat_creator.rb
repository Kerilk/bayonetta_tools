#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

input_dir = ARGV[0]

raise "Not a directory: #{input_dir}!" unless File.directory?(input_dir)

Dir.chdir(input_dir)
Dir.mkdir("dat_output") unless Dir.exist?("dat_output")

big = YAML::load_file(".metadata/big.yaml")

d = Bayonetta::DATFile::new(nil, big)

d.layout = YAML::load_file(".metadata/layout.yaml")

d.layout.each { |fname|
  d.push(fname, File::new(fname, "rb") )
}

extension = ".dat"
extension = YAML::load_file(".metadata/extension.yaml")
suffix = extension.gsub(".", "_")

d.dump("dat_output/#{File.basename(input_dir).gsub(suffix, "")}#{extension}")
