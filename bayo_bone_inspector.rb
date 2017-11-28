#!ruby
require 'set'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

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
  tt = wmb.bone_index_translate_table.table
  bone_set &= tt.collect{ |mot_index, bone_index| mot_index }
}

puts YAML::dump(bone_set.to_a)
