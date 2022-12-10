require 'optparse'
require_relative '../../bayonetta'
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

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wtb_convert_wiiu_pc target_file
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--output=filename", "file to output result") do |name|
    $options[:output] = name
  end

end.parse!

input_file = ARGV[0]

raise "Invalid file #{input_file}" unless input_file && File::file?(input_file)

if File.extname(input_file) == ".wta"
  fl = WTBFile::new(File::new(input_file, "rb"), true, File::new(input_file.gsub(/wta\z/,"wtp"), "rb"))
else
  fl = WTBFile::new(File::new(input_file, "rb"))
end
Dir.mkdir("tex_output") unless Dir.exist?("tex_output")
prefix = File.join("tex_output", File.basename(input_file, ".wtb"))
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

texs.each { |name, info|
  flags, idx = info
  if File.extname(input_file) == ".wta"
    flags &= 0xffffffdf #remove 0x20 flag
    if flags == 0x70000000
      flags = 0x10000000
    else
      flags = 0x20000000
    end
  else
    flags &= 0xfffffffd #remove 0x2 flag
  end
  new_name = name.gsub("gtx","dds")
  raise "could not locate TexConv2.exe, put it in your PATH" unless tex_conv_path
  res = `#{Shellwords.escape tex_conv_path} -i #{Shellwords.escape name} -o #{Shellwords.escape new_name}`
  raise "could not execute TexConv2.exe:\n#{res}" if !$?.success?
  fl2.push( File::new(new_name, "rb"), flags, idx )
}

output_file = $options[:output]
if !output_file
  Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
  output_file = File.join("wtb_output", "#{File.basename(input_file.gsub(/wta\z/,"wtb"))}")
end
fl2.dump(output_file)

