#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

filename = ARGV[0]
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)


raise "Invalid file (#{name})!" unless ext_name == ".scr"

f = File::open(filename, "rb")
Dir.chdir(directory)
dir_name = File.basename(name, ext_name) + "#{ext_name.gsub(".","_")}"
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

scr = Bayonetta::SCRFile::load(f)

scr.each_model.each_with_index { |f1, i|
  File::open("%03d.wmb" % [i] , "wb") { |f2|
    f1.rewind
    f2.write(f1.read)
  }
}

f1 = scr.textures
if f1
  File::open("000.wtb", "wb") { |f2|
    f1.rewind
    f2.write(f1.read)
  }
end

Dir.mkdir(".metadata") unless Dir.exist?(".metadata")
Dir.chdir(".metadata")
File::open("models_metadata.yaml", "w") { |fl|
  fl.print YAML::dump( scr.models_metadata )
}
File::open("big.yaml","w") { |fl|
  fl.print YAML::dump( scr.big )
}
File::open("bayo2.yaml","w") { |fl|
  fl.print YAML::dump( scr.bayo2? )
}
File::open("unknown.yaml", "w") { |fl|
  fl.print YAML::dump( scr.unknown )
}
