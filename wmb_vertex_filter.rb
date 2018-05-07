#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :mesh => 0,
  :batch => :all,
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_vertex_extract.rb target_file vertex_list [options]"

  opts.on("-m", "--mesh=INDEX", "Mesh to filter") do |index|
    $options[:mesh] = index.to_i
  end

  opts.on("-b", "--batches=INDEXES", "Batches to filter") do |index|
    $options[:batch] = eval(index).to_a unless index == ":all"
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--overwrite", "Overwrite input file") do |overwrite|
    $options[:overwrite] = overwrite
  end

end.parse!


input_file = ARGV[0]
vertex_list = ARGV[1]

raise "Invalid file #{input_file}" unless File::file?(input_file)
raise "Invalid file #{vertex_list}" unless File::file?(vertex_list)
wmb = WMBFile::load(input_file)
vl = YAML::load_file(vertex_list)

if $options[:batch] == :all
  wmb.meshes[$options[:mesh]].batches.each { |batch|
    batch.filter_vertexes( vl )
  }
else
  $options[:batch].each { |i|
    batch = wmb.meshes[$options[:mesh]].batches[i]
    batch.filter_vertexes( vl )
  }
end
wmb.meshes[$options[:mesh]].batches.select! { |batch| batch.header.num_indices > 0 }

Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
#wmb.cleanup_vertexes
wmb.recompute_layout
if $options[:overwrite]
  wmb.dump(input_file, wmb.was_big? )
else
  wmb.dump("wmb_output/"+File.basename(input_file), wmb.was_big? )
end
