#!ruby
require 'optparse'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :vertexes => true,
  :bones => false,
  :swap => nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_cleanup.rb target_file [options]"

  opts.on("-b", "--[no-]bones", "Cleanup bones") do |bones|
    $options[:bones] = bones
  end

  opts.on("-v", "--[no-]vertexes", "Cleanup vertexes") do |vertexes|
    $options[:vertexes] = vertexes
  end

  opts.on("-e", "--swap-endianness", "Swap endianness") do |swap|
    $options[:swap] = swap
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
wmb = WMBFile::load(input_file)
wmb.cleanup_bones if $options[:bones]
wmb.cleanup_vertexes if $options[:vertexes]
wmb.recompute_layout
wmb.dump("wmb_output/"+File.basename(input_file), $options[:swap] ? !wmb.was_big? : wmb.was_big? )
