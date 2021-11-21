require 'set'
require 'yaml'
require 'optparse'
require_relative '../../bayonetta'
include Bayonetta

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wmb_common_bones target_file [target_file2 ...]
  This script finds the common bones between a list of models.
  This was used to find the minimal skeleton.
  Target files should be dat files or wmb files.
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

bone_set = Set::new
bone_set.merge((0..0xfff).to_a)
found = false
ARGV.each { |input_file|
  raise "Invalid file #{input_file}" unless File::file?(input_file)
  if File.extname(input_file) == ".dat"
    search = File.basename(input_file, ".dat")+".wmb"
    wmb = DATFile::load(input_file).each.select { |name, f|
      name == search
    }.first
    if !wmb
      warn "Could not find #{search} in #{File.basename(input_file)}"
      next
    end
    wmb = wmb[1]
    wmb = WMBFile::load(wmb)
  else
    wmb = WMBFile::load(input_file)
  end
  found = true
  tt = wmb.bone_index_translate_table.table
  bone_set &= tt.collect{ |mot_index, bone_index| mot_index }
}

puts YAML::dump(bone_set.to_a) if found
