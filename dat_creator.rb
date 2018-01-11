#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

input_dir = ARGV[0]

raise "Not a directory: #{ARGV[0]}!" unless File.directory?(ARGV[0])

files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) }
Dir.mkdir("dat_output") unless Dir.exist?("dat_output")

big = false
big = YAML::load_file(".metadata/big.yaml") if File.exist?(".metadata/big.yaml")

d = Bayonetta::DATFile::new(nil, big)

files.each { |fname|
  d.push(fname, File::new(fname, "rb") )
}

d.layout = YAML::load_file(".metadata/layout.yaml") if File.exist?(".metadata/layout.yaml")

extension = ".dat"
extension = YAML::load_file(".metadata/extension.yaml") if File.exist?(".metadata/extension.yaml")
suffix = extension.gsub(".", "_")

d.dump("dat_output/#{File.basename(ARGV[0]).gsub(suffix, "")}#{extension}")
