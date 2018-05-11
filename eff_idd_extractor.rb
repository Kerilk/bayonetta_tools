#!ruby
require 'yaml'
require_relative 'lib/bayonetta.rb'

filename = ARGV[0]
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)

raise "Invalid file (#{name})!" unless ext_name == ".eff" || ext_name == ".idd"

f = File::open(filename, "rb")

Dir.chdir(directory)
dir_name = File.basename(name, ext_name) + "#{ext_name.gsub(".","_")}"
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

eff = Bayonetta::EFFFile::new(f)

eff.each_directory { |id, dir|
  Dir.mkdir(dir.name) unless Dir.exist?(dir.name)
  dir.each { |fname, f2|
    File::open("#{dir.name}/#{fname}", "wb") { |f3|
      f2.rewind
      f3.write(f2.read)
    }
  }
}

Dir.mkdir(".metadata") unless Dir.exist?(".metadata")
Dir.chdir(".metadata")
File::open("id.yaml", "w") { |fl|
  fl.print YAML::dump( eff.id )
}
File::open("layout.yaml", "w") { |fl|
  fl.print YAML::dump( eff.layout )
}
File::open("extension.yaml", "w") { |fl|
  fl.print YAML::dump( ext_name )
}
File::open("big.yaml","w") { |fl|
  fl.print YAML::dump( eff.big )
}
