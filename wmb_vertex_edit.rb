#!ruby
require 'optparse'
require 'yaml'
require 'nyaplot'
require 'nyaplot3d'

require_relative 'lib/bayonetta.rb'
include Bayonetta

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

def normalize(n)
  l = Math.sqrt(n[0]**2 + n[1]**2 + n[2]**2)
  [n[0]/l, n[1]/l, n[2]/l]
end

def distance(n, v)
  n[0]*v[0] +  n[1]*v[1] +  n[2]*v[2]
end

def cluster(v)
  n = [0.0, 0.1, 0.029]
  n = normalize(n)
  vs = v.sort { |v1, v2| distance(n, v1) <=> distance(n, v2) }
  #vs.collect{ |v| distance(n, v) }


  res = [vs[0..-82], vs[-81..-55],vs[-54..-28], vs[-27..-1]]
  res.collect(&:transpose)
end

def cluster_with_index(v)
  n = [0.0, 0.1, 0.029]
  n = normalize(n)
  vs = v.to_a.sort { |(_, v1), (_, v2)| distance(n, v1) <=> distance(n, v2) }
  puts YAML::dump vs[-54..-28].sort { |(_, v1), (_, v2)| v1[2] <=> v2[2] }
  vs[-81..-1]
end


v = vertexes.collect{ |i, v| [v[0], v[1], v[2]] }
vs = cluster(v)
shapes = ['circle', 'cross', 'rect', 'diamond']
vs.each_with_index { |v, i|
  sc = plot.add(:scatter, v[0], v[1], v[2])
  sc.shape(shapes[i])
}

plot.add(:line, [0.0, 0.0], [0.1, 0.20], [-0.03, -0.007])

plot.export_html("3dscatter.html")

res = cluster_with_index(vertexes)

vs = res.collect{ |i, v| [v[0], v[1] - 1.5, v[2]] }
vs = vs.transpose

plot = Nyaplot::Plot3D.new

sc = plot.add(:scatter, vs[0], vs[1], vs[2])

plot.export_html("3dscatter2.html")
puts YAML::dump( res.collect{ |i,v| i }.sort )
