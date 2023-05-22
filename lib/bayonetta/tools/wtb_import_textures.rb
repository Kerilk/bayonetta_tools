require 'optparse'
require_relative '../../bayonetta.rb'
require 'shellwords'
include Bayonetta

# https://stackoverflow.com/a/5471032
def which(cmd)
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exe = File.join(path, cmd)
    return exe if File.executable?(exe) && !File.directory?(exe)
  end
  nil
end

$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: wtb_import_textures.rb target_file source_file [options]"

  opts.on("-o", "--[no-]overwrite", "Overwrite destination file") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

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
prefix = File.join("tex_output", File.basename(input_file2, ".wtb"))
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

tex_conv_path = which("TexConv2.exe")
if !tex_conv_path
  tex_conv_path = File.join(".", "TexConv2.exe")
  if (!File.exist?(tex_conv_path))
    tex_conv_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), *[".."]*3)), "TexConv2.exe")
    if (!File.exist?(tex_conv_path))
      tex_conv_path = nil
    end
  end
end

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
    raise "could not locate TexConv2.exe, put it in your PATH" unless tex_conv_path
    res = `#{Shellwords.escape tex_conv_path} -i #{Shellwords.escape name} -o #{Shellwords.escape new_name}`
    raise "could not execute TexConv2.exe:\n#{res}" if !$?.success?
  else
    new_name = name
  end
  fl2.push( File::new(new_name, "rb"), flags, nil )
}

if $options[:overwrite]
  fl2.dump(input_file1)
else
  Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
  fl2.dump(File.join("wtb_output", File.basename(input_file1)))
end
