#!ruby
require_relative 'lib/bayonetta.rb'
include Bayonetta


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
fl = WMBFile::convert(input_file, "wmb_output/"+File.basename(input_file))
#wmb = WMBFile::load(input_file)
#wmb.dump("wmb_output/"+File.basename(input_file))
