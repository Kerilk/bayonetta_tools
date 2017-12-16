#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :mesh => 0,
  :batch => 0,
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_vertex_extract.rb target_file [options]"

  opts.on("-m", "--mesh=INDEX", "Mesh to dump") do |index|
    $options[:mesh] = index.to_i
  end

  opts.on("-b", "--batch=INDEX", "Batch to dump") do |index|
    $options[:batch] = index.to_i
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
wmb = WMBFile::load(input_file)

batch = wmb.meshes[$options[:mesh]].batches[$options[:batch]]
vertexes = wmb.vertexes
vertex_indices = batch.header.vertex_start...batch.header.vertex_end
print YAML::dump vertex_indices.collect { |i| [i, [vertexes[i].x, vertexes[i].y, vertexes[i].z] ] }.to_h


