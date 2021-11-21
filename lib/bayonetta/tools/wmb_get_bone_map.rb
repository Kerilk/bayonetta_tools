require 'set'
require 'yaml'
require 'optparse'
require_relative '../../bayonetta'
include Bayonetta

$options = {
  filter: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wmb_get_bone_map target_file
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-f", "--filter=YAML_FILE", "A YAML file containing the list of global bones to get the mapping for") do |f|
    $options[:filter] = f
  end

end.parse!

def decode_bone_index_translate_table(wmb, filter=nil)
  table = wmb.bone_index_translate_table.table.dup
  table.select! { |k,v| filter.include?(k) } if filter
  table
end

input_file = ARGV[0]
filter = $options[:filter]
if filter
  raise "Invalid filter file: #{filter}!" unless File.exist?(filter)
  f = YAML::load_file(filter).to_set
else
  f = nil
end

raise "Invalid file #{input_file}" unless input_file && File::file?(input_file)
if File.extname(input_file) == ".dat"
  wmb = DATFile::load(input_file).each.select { |name, f|
    name == File.basename(input_file, ".dat")+".wmb"
  }.first[1]
  wmb = WMBFile::load(wmb)
else
  wmb = WMBFile::load(input_file)
end
puts YAML::dump decode_bone_index_translate_table(wmb, f).to_h
