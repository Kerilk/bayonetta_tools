require 'set'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

def decode_bone_index_translate_table(wmb)
  table = wmb.bone_index_translate_table.table
  (0x0..0xfff).each.collect { |i|
    index = table[(i & 0xf00)>>8]
    next if index == -1
    index = table[index + ((i & 0xf0)>>4)]
    next if index == -1
    index = table[index + (i & 0xf)]
    next if index == 0xfff
    [i, index]
  }.compact
end

bone_set = Set::new
bone_set.merge((0..0xfff).to_a)

ARGV.each { |input_file|
  raise "Invalid file #{input_file}" unless File::file?(input_file)
  if File.extname(input_file) == ".dat"
    wmb = DATFile::new(input_file, true).each.select { |name, f|
      name == File.basename(input_file, ".dat")+".wmb"
    }.first[1]
    wmb = WMBFile::load(wmb)
  else
    wmb = WMBFile::load(input_file)
  end
  tt = decode_bone_index_translate_table(wmb)
  bone_set &= tt.collect{ |mot_index, bone_index| mot_index }
}

puts YAML::dump(bone_set.to_a)
