require_relative 'lib/bayonetta.rb'
include Bayonetta


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
fl = WTBFileLayout::load(input_file)
Dir.mkdir("tex_output") unless Dir.exist?("tex_output")
prefix = "tex_output/"+File.basename(input_file, ".wtb")
tex_names = fl.dump_textures(prefix)
new_texs = tex_names.collect { |name|
  new_name = name.gsub("gtx","dds")
  `./TexConv2.exe -i "#{name}" -o "#{new_name}"`
  BayoTex::new(new_name)
}
fl2 = WTBFileLayout::from_files(new_texs)
fl2.unknown = fl.unknown
fl2.texture_flags = fl.texture_flags
fl2.texture_idx = fl.texture_idx
Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
fl2.dump("wtb_output/"+File.basename(input_file))
#fl.dump("toto.wtb", true)
