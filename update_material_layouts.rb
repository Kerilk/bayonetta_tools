require 'yaml'

database = YAML::load_file('lib/bayonetta/material_database.yaml')

File::open('material_struct.c') { |f|
  str = f.read
  res = str.scan(/^typedef struct {\n(.*?)} mat_(\h\h)_values_t;/m)
  res.collect { |m|
    [m[1].to_i(16) , m[0].tr(";","").split("\n").collect(&:split).collect(&:reverse).to_h ]
  }.each { |mat_id, layout|
    database[mat_id][:layout] = layout
  }
}
File::open('lib/bayonetta/material_database.yaml', "w") { |f|
  f.write YAML::dump(database)
}
