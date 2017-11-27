require_relative 'lib/bayonetta'

filename = ARGV[0]
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)

raise "Invalid file (#{name})!" unless ext_name == ".wta" ||  ext_name == ".wtb"

f = File::open(filename, "rb")

Dir.chdir(directory)
tex_name = File.basename(name, ext_name)
if ext_name == ".wta"
  wtp_name = tex_name + ".wtp"
  f_wtp = File::open(wtp_name, "rb")
  dir_name = tex_name + "_wta"
else
  f_wtp = nil
  dir_name = tex_name + "_wtb"
end
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

wtb =  Bayonetta::WTBFile::new(f, true, f_wtp)

wtb.each.each_with_index { |info_f, i|
  info, f = info_f
  ext, _, _ = info
  File::open("#{tex_name}_#{"%03d"%i}#{ext}", "wb") { |f2|
    f.rewind
    f2.write(f.read)
  }
}

