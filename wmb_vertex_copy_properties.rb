#!ruby
require 'optparse'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  position: true,
  mapping: false,
  normal: true,
  tangents: false,
  bone_infos: true,
  unknown: false,
  color: false,
  bone_map: nil
}


OptionParser.new do |opts|
  opts.banner = "Usage: wmb_vertex_copy_properties.rb TARGETFILE SOURCE_DEST_HASH [options]"

  opts.on("-p", "--[no-]position", "Copy vertex position (default true)") { |p|
    $options[:position] = p
  }

  opts.on("-m", "--[no-]mapping", "Copy vertex mapping (default false) (in ex data also)") { |m|
    $options[:mapping] = m
  }

  opts.on("-n", "--[no-]normal", "Copy vertex normal (default true)") { |n|
    $options[:normal] = n
  }

  opts.on("-t", "--[no-]tangents", "Copy vertex tangeants (default false)") { |t|
    $options[:tangents] = t
  }

  opts.on("-b", "--[no-]bone-infos", "Copy bone indexes and weights (default true)") { |b|
    $options[:bone_infos] = b
  }

  opts.on("-c", "--[no-]color", "Copy color") { |c|
    $options[:color] = c
  }

  opts.on("-u", "--[no-]unknown", "Copy the unknown field in ex data (default false)") { |u|
    $options[:unknown] = u
  }

  opts.on("--[no-]texture_infos", "Activates (deactivates) -mt") { |tex|
    $options[:mapping] = tex
    $options[:tangents] = tex
  }

  opts.on("--overwrite", "Overwrite input file") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

input_file = ARGV[0]
vertex_hash = eval(ARGV[1]).to_h

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
wmb = WMBFile::load(input_file)

wmb.copy_vertex_properties(vertex_hash, **$options)

if $options[:overwrite]
  wmb.dump(input_file, wmb.was_big? )
else
  wmb.dump("wmb_output/"+File.basename(input_file), wmb.was_big? )
end
