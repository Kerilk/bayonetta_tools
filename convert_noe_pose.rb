require 'yaml'

h = YAML::load_file(ARGV[0])

h.each { |k, v|
  x = -v[5] * Math::PI/180.0
  y = v[3] * Math::PI/180.0
  z = -v[4] * Math::PI/180.0
  v[3] = x
  v[4] = y
  v[5] = z
}


if ARGV[1]
  File::write(ARGV[1], h.to_yaml)
else
  puts YAML::dump(h)
end
