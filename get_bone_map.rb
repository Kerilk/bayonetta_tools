require 'set'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

def decode_bone_index_translate_table(wmb, filter=nil)
  table = wmb.bone_index_translate_table.table.dup
  table.select! { |k,v| filter.include?(k) } if filter
  table
end


input_file = ARGV[0]
filter = ARGV[1]
if filter
  f = YAML::load_file(filter).to_set
else
  f = nil
end

raise "Invalid file #{input_file}" unless File::file?(input_file)
if File.extname(input_file) == ".dat"
  wmb = DATFile::new(input_file).each.select { |name, f|
    name == File.basename(input_file, ".dat")+".wmb"
  }.first[1]
  wmb = WMBFile::load(wmb)
else
  wmb = WMBFile::load(input_file)
end
puts YAML::dump decode_bone_index_translate_table(wmb, f).to_h

