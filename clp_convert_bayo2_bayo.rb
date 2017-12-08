#!ruby
require 'optparse'
require_relative 'lib/bayonetta.rb'
include Bayonetta
$bone_map = {
 4095 => 4095
}
$options = {
  :remap_bones => false,
}
OptionParser.new do |opts|
  opts.banner = "Usage: clp_convert_bayo2_bayo.rb target_file [options]"

  opts.on("-r", "--remap-bones=BONELISTS", "Remap specified bones, lists separated by _") do |bone_lists|
    $options[:remap_bones] = true
    lists = bone_lists.split("/")
    input_list = eval(lists.first).to_a
    output_list = eval(lists.last).to_a
    $bone_map.merge! input_list.zip(output_list).to_h
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

Dir.mkdir("clp_output") unless Dir.exist?("clp_output")

input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)

clp = CLPFile::load_bxm(input_file)

clp.remap($bone_map) if $options[:remap_bones]

clp.dump("clp_output/#{File.basename(ARGV[0]).gsub("_clp.bxm",".clp")}")
