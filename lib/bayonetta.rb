require_relative 'bayonetta/endianness'
require_relative 'bayonetta/alignment'
require_relative 'bayonetta/bone'
require_relative 'bayonetta/data_converter'
require_relative 'bayonetta/dat'
require_relative 'bayonetta/eff'
require_relative 'bayonetta/idd'
require_relative 'bayonetta/wtb'
require_relative 'bayonetta/wmb'
require_relative 'bayonetta/exp'
require_relative 'bayonetta/bxm'
require_relative 'bayonetta/clp'
require_relative 'bayonetta/clh'
require_relative 'bayonetta/clw'

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

  def self.create_eff(dirname, big=false)
    pwd = Dir.pwd

    file_name = File.basename(dirname).gsub("_eff", "")
    dirs = Dir.entries(dirname)
    Dir.chdir(dirname)
    pwd_basedir = Dir.pwd

    dirs.select! { |f| File.directory?(f) and f.match(/\d{2}_.../) }
    dirs.sort!
    eff = EFFFile::new(nil, big)
    dirs.each { |dname|
      d = EFFFile::Directory::new(nil, big)
      d.name = dname[3..-1]
      fnames = Dir.entries("#{dname}")
      Dir.chdir(dname)
      fnames.select! { |f| File.file?(f) }
      fnames.sort!
      fnames.each { |fname|
        d.push( File::basename(fname, File::extname(fname)).to_i, File::new(fname, "rb"))
      }
      eff.push(dname[0..2].to_i, d)
      Dir.chdir(pwd_basedir)
    }
    Dir.mkdir("eff_output") unless Dir.exist?("eff_output")
    Dir.chdir("eff_output")
    File::open(file_name+".eff", "wb") { |f|
      f.write eff.to_stringio.read
    }
  end

  def self.extract_idd(filename, big=false)

    directory = File.dirname(filename)
    name = File.basename(filename)
    ext_name = File.extname(name)

    raise "Invalid file (#{name})!" unless ext_name == ".idd"

    f = File::new(filename, "rb")

    Dir.chdir(directory)
    dir_name = File.basename(name, ext_name)+"_idd"
    Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
    Dir.chdir(dir_name)

    eff = IDDFile::new(f, big)

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

  def self.create_idd(dirname, big=false)
    pwd = Dir.pwd

    file_name = File.basename(dirname).gsub("_idd", "")
    dirs = Dir.entries(dirname)
    Dir.chdir(dirname)
    pwd_basedir = Dir.pwd

    dirs.select! { |f| File.directory?(f) and f.match(/\d{2}_.../) }
    dirs.sort!
    eff = IDDFile::new(nil, big)
    dirs.each { |dname|
      d = IDDFile::Directory::new(nil, big)
      d.name = dname[3..-1]
      fnames = Dir.entries("#{dname}")
      Dir.chdir(dname)
      fnames.select! { |f| File.file?(f) }
      fnames.sort!
      fnames.each { |fname|
        d.push( File::basename(fname, File::extname(fname)).to_i, File::new(fname, "rb"))
      }
      eff.push(dname[0..2].to_i, d)
      Dir.chdir(pwd_basedir)
    }
    Dir.mkdir("idd_output") unless Dir.exist?("idd_output")
    Dir.chdir("idd_output")
    File::open(file_name+".idd", "wb") { |f|
      f.write eff.to_stringio.read
    }
  end

end
