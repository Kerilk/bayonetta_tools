#!ruby
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

input_dir = ARGV[0]


files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) && [".gtx", ".dds", ".bntx"].include?( File.extname(f) ) }
files.sort!
puts files
Dir.mkdir("wtx_output") unless Dir.exist?("wtx_output")
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


wtb.dump("wtx_output/#{File.basename(ARGV[0]).gsub("_wta","").gsub("_wtb", "")}#{extension}")

