#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :bones => nil,
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_dump_bones.rb target_file [options]"

  opts.on("-b", "--bones=BONELIST", "Dump specified bones") do |bone_list|
    $options[:bones] = eval(bone_list).to_a
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

input_file = ARGV[0]
raise "Invalid file #{input_file}" unless File::file?(input_file)
wmb = WMBFile::load(input_file)
puts YAML::dump( wmb.dump_bones($options[:bones]) )

