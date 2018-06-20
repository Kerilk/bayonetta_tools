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
  :reject => false,
  :cut => 0,
  :positions => false,
  :size => 0.5,
  :order => 2
}

def normalize(n)
  l = Math.sqrt(n[0]**2 + n[1]**2 + n[2]**2)
  [n[0]/l, n[1]/l, n[2]/l]
end

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_vertex_edit.rb [options]"

  opts.on("-c", "--cut=NUMMBER", "Keep (reject) NUMBER vertexes") do |cut|
    $options[:cut] = cut.to_i
  end

  opts.on("-n", "--normal=VECTOR", "normal vector (default [0.0, 1.0, 0.0])") do |vector|
    $options[:vector] = normalize(eval(vector).to_a)
  end

  opts.on("-p", "--point=POINT", "base point (default [0.0, 0.0, 0.0])") do |point|
    $options[:point] = eval(point).to_a
  end

  opts.on("-r", "--[no-]reject", "Reject rather than select vertexes") do |reject|
    $options[:reject] = reject
  end

  opts.on("-s", "--[no-]split", "Split vertexes keeping (rejecting) those below the plane") do |split|
    $options[:split] = split
  end

  opts.on("--[no-]output-with-positions", "Output vertex indexes and positions") do |positions|
    $options[:positions] = positions
  end

  opts.on("--positions-order=INDEX", "Sort vertexes by index when using vertex indexes and positions (default 2)") do |order|
    $options[:order] = order
  end

  opts.on("--size=VALUE", "Change the size of the points in the scatter plot (default 0.5)") do |size|
    $options[:size] = size.to_f
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

cut = $options[:cut]

vertexes = YAML::load($stdin.read).to_a

plot = Nyaplot::Plot3D.new

def position(n, p, v)
  s = n[0]*(v[0]-p[0])+n[1]*(v[1]-p[1])+n[2]*(v[2]-p[2])
end

def distance(n, p, v)
  position(n, p, v).abs
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

def split(n, p, v)
  res = [[],[]]
  v.each { |v1|
    if  position(n, p, v1) <= 0.0
      res[0].push v1
    else
      res[1].push v1
    end
  }
  res = [res[1], res[0]] if $options[:reject]
  res.collect(&:transpose)
end

def split_with_index(n, p, v)
  res = [[],[]]
  v.to_a.each { |k, v1|
    if  position(n, p, v1) <= 0.0
      res[0].push [k,v1]
    else
      res[1].push [k,v1]
    end
  }
  res = [res[1], res[0]] if $options[:reject]
  res[0]
end

v = vertexes.collect{ |i, v| [v[0], v[1], v[2]] }
if $options[:split]
  vs = split($options[:vector], $options[:point], v)
else
  vs = cluster($options[:vector], $options[:point], v, cut)
end
shapes = ['circle', 'cross']
vs.each_with_index { |v, i|
  next if v.empty?
  sc = plot.add(:scatter, v[0].collect { |x| x-$options[:point][0] },
                          v[1].collect { |y| y-$options[:point][1] },
                          v[2].collect { |z| z-$options[:point][2] }
               )
  sc.shape(shapes[i])
  sc.size($options[:size])
}

plot.export_html("3dscatter.html")

if $options[:split]
  res = split_with_index($options[:vector], $options[:point], vertexes)
else
  res = cluster_with_index($options[:vector], $options[:point], vertexes, cut)
end
vs = res.collect{ |i, v| [v[0], v[1], v[2]] }
vs = vs.transpose
vs = [[],[],[]] if vs.empty?

plot = Nyaplot::Plot3D.new

sc = plot.add(:scatter, vs[0].collect { |x| x-$options[:point][0] },
                        vs[1].collect { |y| y-$options[:point][1] },
                        vs[2].collect { |z| z-$options[:point][2] })

plot.export_html("3dscatter2.html")
if $options[:positions]
  puts YAML::dump( res.collect{ |i,v| [i,v] }.sort { |(i1,v1),(i2,v2)| v1[$options[:order]] <=> v2[$options[:order]] } )
else
  puts YAML::dump( res.collect{ |i,_| i }.sort )
end
