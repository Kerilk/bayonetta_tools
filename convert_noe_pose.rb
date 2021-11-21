require 'yaml'

h = YAML::load_file(ARGV[0])
coef = Math::PI/180.0
h.each { |k, v|
  x = -v[5] * coef if v[5]
  y = v[3] * coef if v[3]
  z = -v[4] * coef if v[4]
  v[3] = x if v[5]
  v[4] = y if v[3]
  v[5] = z if v[4]
}


if ARGV[1]
  File::write(ARGV[1], h.to_yaml)
else
  puts YAML::dump(h)
end
