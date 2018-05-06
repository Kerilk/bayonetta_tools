#!ruby
require 'optparse'
require 'yaml'
require 'nyaplot'
require 'nyaplot3d'

require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :vector => [0.0, 1.0, 0.0],
  :point => [0.0, 0.0, 0.0],
  :reject => false
}

def normalize(n)
  l = Math.sqrt(n[0]**2 + n[1]**2 + n[2]**2)
  [n[0]/l, n[1]/l, n[2]/l]
end

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_vertex_edit.rb NUMBER [options]"

  opts.on("-n", "--normal=VECTOR", "normal vector (default [0.0, 1.0, 0.0])") do |vector|
    $options[:vector] = normalize(eval(vector).to_a)
  end

  opts.on("-p", "--point=POINT", "base point (default [0.0, 0.0, 0.0])") do |point|
    $options[:point] = eval(point).to_a
  end

  opts.on("-r", "--[no-]reject", "Reject rather than select vertexes") do |reject|
    $options[:reject] = reject
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

cut = ARGV[0].to_i

vertexes = YAML::load($stdin.read).to_a

#print YAML::dump vertexes.sort { |(i, vi), (j, vj)|
#  vi[1] <=> vj[1]
#}
# Scatter
plot = Nyaplot::Plot3D.new
#colors = ['#8dd3c7', '#ffffb3', '#bebada', '#fb8072']
#['circle', 'rect', 'rect', 'diamond'].each do |shape|
#  x, y, z = [0,0,0].map{|d| next Array.new(20, rand*5).map{|v| next v+rand}}
#  sc = plot.add(:scatter, x, y, z)
#  sc.shape(shape)
#  sc.fill_color(colors.pop)
#end

def distance(n, p, v)
	(n[0]*v[0] +  n[1]*v[1] +  n[2]*v[2] - (n[0]*p[0] + n[1]*p[1] + n[2]*p[2])).abs
end

def cluster(n, p, v, cut)
  vs = v.sort { |v1, v2| distance(n, p, v1) <=> distance(n, p, v2) }
  res = [vs[0..cut], vs[(cut+1)..-1]]
  res = [res[1], res[0]] if $options[:reject]
  res.collect(&:transpose)
end

def cluster_with_index(n, p, v, cut)
  vs = v.to_a.sort { |(_, v1), (_, v2)| distance(n, p, v1) <=> distance(n, p, v2) }
  if $options[:reject]
    vs[(cut+1)..-1]
  else
    vs[0..cut]
  end
end

v = vertexes.collect{ |i, v| [v[0], v[1], v[2]] }
vs = cluster($options[:vector], $options[:point], v, cut)
shapes = ['circle', 'cross']
vs.each_with_index { |v, i|
  sc = plot.add(:scatter, v[0], v[1], v[2])
  sc.shape(shapes[i])
  sc.size(0.5)
}

#plot.add(:line, [0.0, 0.0], [0.0, 0.10], [-0.00, -0.00])

plot.export_html("3dscatter.html")


res = cluster_with_index($options[:vector], $options[:point], vertexes, cut)
vs = res.collect{ |i, v| [v[0], v[1], v[2]] }
vs = vs.transpose

plot = Nyaplot::Plot3D.new

sc = plot.add(:scatter, vs[0], vs[1], vs[2])

plot.export_html("3dscatter2.html")
puts YAML::dump( res.collect{ |i,v| i }.sort )
