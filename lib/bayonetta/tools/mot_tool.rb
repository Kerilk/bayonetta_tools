require 'optparse'
require 'yaml'
require_relative '../../bayonetta'
include Bayonetta

$options = {
  decode: false,
  decode_frame: nil,
  swap: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: mot_tool.rb target_file [options]"

  opts.on("--remap-bones=HASH", "Remap bones in the motion file") { |remap_bones|
    $options[:remap_bones] = YAML::load_file(remap_bones)
  }

  opts.on("--[no-]decode", "Decode motion file") { |decode|
    $options[:decode] = decode
  }

  opts.on("--decode-frame=FRAME_INDEX", "Decode a motion frame") { |decode_frame|
    $options[:decode_frame] = decode_frame.to_i
  }

  opts.on("--[no-]overwrite", "Overwrite source file") { |overwrite|
    $options[:overwrite] = overwrite
  }

  opts.on("-e", "--swap-endianness", "Swap endianness") do |swap|
    $options[:swap] = swap
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

Dir.mkdir("mot_output") unless Dir.exist?("mot_output")
input_file = ARGV[0]
raise "Invalid file #{input_file}" unless File::file?(input_file)

mot = MOTFile::load(input_file)

mot.remap_bones($options[:remap_bones]) if $options[:remap_bones]

if $options[:decode] || $options[:decode_frame]
  puts YAML::dump(mot.decode) if $options[:decode]
  puts YAML::dump(mot.decode_frame($options[:decode_frame])) if $options[:decode_frame]
  exit
end

if $options[:overwrite]
  mot.dump(input_file, $options[:swap] ? !mot.was_big? : mot.was_big?)
else
  mot.dump("mot_output/"+File.basename(input_file), $options[:swap] ? !mot.was_big? : mot.was_big?)
end
