require_relative 'lib/bayonetta.rb'
include Bayonetta


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
fl = WTBFile::new(File::new(input_file, "rb"))
Dir.mkdir("tex_output") unless Dir.exist?("tex_output")
prefix = "tex_output/"+File.basename(input_file, ".wtb")
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

texs.each { |name, info|
  flags, idx = info
  flags &= 0xfffffffd #remove 0x2 flag
  new_name = name.gsub("gtx","dds")
  `#{path}/TexConv2.exe -i "#{name}" -o "#{new_name}"`
  fl2.push( File::new(new_name, "rb"), flags, idx )
}

Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
fl2.dump("wtb_output/#{File.basename(input_file)}")

