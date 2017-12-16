#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_import_bones.rb target_file bone_def"

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

input_file = ARGV[0]
bone_def = ARGV[1]
raise "Invalid file #{input_file}" unless File::file?(input_file)
raise "Invalid file #{bone_def}" unless File::file?(bone_def)
bones = YAML::load_file( bone_def )
wmb = WMBFile::load(input_file)

wmb.import_bones(bones)
wmb.recompute_layout
Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
wmb.dump("wmb_output/"+File.basename(input_file), wmb.was_big? )
