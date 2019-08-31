require 'zstd-ruby'
require_relative 'lib/bayonetta'

save_pwd = Dir.pwd

ARGV.each { |filename|
  directory = File.dirname(filename)
  name = File.basename(filename)
  ext_name = File.extname(name)
  raise "Invalid file (#{name})!" unless ext_name == ".pkz"

  f = File::open(filename, "rb")

  Dir.chdir(directory)
  pkz = Bayonetta::PKZFile::load(f)

  name_table_offset = pkz.header.offset_file_descriptors + pkz.header.num_files * 0x20
  pkz.file_descriptors.each { |d|
    f.seek(d.offset_name + name_table_offset)
    name = f.read(16).tr("\x00","")
    puts name
    f.seek(d.offset)
    File::open(name, "wb") { |nf|
      nf.write Zstd.decompress(f.read(d.compressed_size))
      raise "Decompression error!" if nf.size != d.size
    }
  }
  Dir.chdir(save_pwd)
  f.close
}
