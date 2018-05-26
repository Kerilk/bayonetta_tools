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
  opts.banner = "Usage: wmb_vertex_extract.rb target_file [options]"

  opts.on("-m", "--mesh=INDEX", "Mesh to dump") do |index|
    $options[:mesh] = index.to_i
  end

  opts.on("-b", "--batches=INDEXES", "Batches to dump") do |index|
    $options[:batch] = eval(index).to_a unless index == ":all"
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
wmb = WMBFile::load(input_file)

vertex_indices = []
if $options[:batch] == :all
  wmb.meshes[$options[:mesh]].batches.each { |batch|
    vertex_indices += batch.indices.collect { |i| i + batch.header.vertex_offset }
  }
else
  $options[:batch].each { |i|
    batch = wmb.meshes[$options[:mesh]].batches[i]
    vertex_indices += batch.indices.collect { |i| i + batch.header.vertex_offset }
  }
end

vertexes = wmb.vertexes
print YAML::dump vertex_indices.collect { |i| [i, [vertexes[i].position.x, vertexes[i].position.y, vertexes[i].position.z] ] }.to_h


