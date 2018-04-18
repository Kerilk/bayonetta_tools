#!ruby
require_relative 'lib/bayonetta.rb'
include Bayonetta

input_file1 = ARGV[0]
input_file2 = ARGV[1]
raise "Invalid file #{input_file1}" unless File::file?(input_file1)
fl0 = WTBFile::new(File::new(input_file1, "rb"))


raise "Invalid file #{input_file2}" unless File::file?(input_file2)
if File.extname(input_file2) == ".wta"
  fl = WTBFile::new(File::new(input_file2, "rb"), true, File::new(input_file2.gsub(/wta\z/,"wtp"), "rb"))
else
  fl = WTBFile::new(File::new(input_file2, "rb"))
end
Dir.mkdir("tex_output") unless Dir.exist?("tex_output")
prefix = "tex_output/"+File.basename(input_file2, ".wtb")
texs = fl.each.each_with_index.collect { |info_f, i|
  info, f = info_f
  ext, flags, idx = info
  tex_name = "#{prefix}_#{"%03d"%i}#{ext}"
  File::open(tex_name, "wb") { |f2|
    f.rewind
    f2.write(f.read)
  }
  [tex_name, [flags, idx]]
}

path = File.expand_path(File.dirname(__FILE__))

fl2 = WTBFile::new
fl2.unknown = fl.unknown

fl0.each { |info, f|
  ext, flags, idx = info
  fl2.push( f, flags, idx )
}

texs.each { |name, info|
  flags, idx = info
  if File.extname(input_file2) == ".wta"
    flags &= 0xffffffdf #remove 0x20 flag
    if flags == 0x70000000
      flags = 0x10000000
    else
      flags = 0x20000000
    end
  elsif fl.big
    flags &= 0xfffffffd #remove 0x2 flag
  end
  if File.extname(name) == ".gtx"
    new_name = name.gsub("gtx","dds")
    `"#{path}/TexConv2.exe" -i "#{name}" -o "#{new_name}"`
  else
    new_name = name
  end
  fl2.push( File::new(new_name, "rb"), flags, nil )
}

Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
fl2.dump("wtb_output/#{File.basename(input_file1)}")

