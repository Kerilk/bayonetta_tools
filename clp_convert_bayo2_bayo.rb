#!ruby
require 'optparse'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta
$bone_map = { }
$options = {
  :remap_bones => false,
  :fix => true,
  :poly => true
}
OptionParser.new do |opts|
  opts.banner = "Usage: clp_convert_bayo2_bayo.rb target_file [options]"

  opts.on("-r", "--remap-bones=BONELISTS", "Remap specified bones, either lists separated by / or a yaml hash table") do |bone_lists|
    $options[:remap_bones] = true
    if File::exist?(bone_lists)
      $bone_map.merge! YAML::load_file(bone_lists)
    else
      lists = bone_lists.split("/")
      p input_list = eval(lists.first).to_a
      p output_list = eval(lists.last).to_a
      $bone_map.merge! input_list.zip(output_list).to_h
    end
  end

  opts.on("-f", "--[no-]fix", "Map no_fix values (default true)") do |fix|
    $options[:fix] = fix
  end

  opts.on("-p", "--[no-]poly", "Map no_poly values (default true)") do |poly|
    $options[:poly] = poly
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

$bone_map.merge!( { 4095 => 4095 } )

Dir.mkdir("clp_output") unless Dir.exist?("clp_output")

input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)

if File.extname(ARGV[0]) == ".bxm"
  clp = CLPFile::load_bxm(input_file)
  clp.remap($bone_map, $options[:poly], $options[:fix]) if $options[:remap_bones]
  clp.dump("clp_output/#{File.basename(ARGV[0]).gsub("_clp.bxm",".clp")}")
else
  clp = CLPFile::load(input_file)
  clp.remap($bone_map, $options[:poly], $options[:fix]) if $options[:remap_bones]
  clp.dump("clp_output/#{File.basename(ARGV[0])}")
end
