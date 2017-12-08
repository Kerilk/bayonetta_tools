require_relative 'bayonetta/endianness'
require_relative 'bayonetta/alignment'
require_relative 'bayonetta/bone'
require_relative 'bayonetta/data_converter'
require_relative 'bayonetta/dat'
require_relative 'bayonetta/eff'
require_relative 'bayonetta/wtb'
require_relative 'bayonetta/wmb'
require_relative 'bayonetta/exp'
require_relative 'bayonetta/bxm'
require_relative 'bayonetta/clp'

module Bayonetta
  include Alignment

  def self.extract_eff(filename, big=false)

    directory = File.dirname(filename)
    name = File.basename(filename)
    ext_name = File.extname(name)

    raise "Invalid file (#{name})!" unless ext_name == ".eff"

    f = File::new(filename, "rb")

    Dir.chdir(directory)
    dir_name = File.basename(name, ext_name)+"_eff"
    Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
    Dir.chdir(dir_name)

    eff = EFFFile::new(f, big)

    eff.each_directory { |id, dir|
      d_name = ("%02d_"%id) + dir.name
      Dir.mkdir(d_name) unless Dir.exist?(d_name)
      dir.each { |fname, f2|
        File::open("#{d_name}/#{fname}", "wb") { |f3|
          f2.rewind
          f3.write(f2.read)
        }
      }
    }

    f.close
  end

end
