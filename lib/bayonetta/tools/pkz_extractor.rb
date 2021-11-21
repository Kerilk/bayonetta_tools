require 'optparse'
require 'zstd-ruby'
require_relative '../../bayonetta'

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: pkz_extractor [pkz_file [pkz_file2 ...]]
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--output=dirname", "directory to output result") do |name|
    $options[:output] = name
  end

end.parse!

save_pwd = Dir.pwd

raise "Invalid output directory #{$options[:output]}" if $options[:output] && !Dir.exist?($options[:output])

ARGV.each { |filename|
  raise "Invalid file: #{filename}!" unless File.exist?(filename)
  directory = File.dirname(filename)
  name = File.basename(filename)
  ext_name = File.extname(name)
  raise "Invalid file (#{name})!" unless ext_name == ".pkz"

  f = File::open(filename, "rb")

  if $options[:output]
    Dir.chdir(save_pwd)
    Dir.chdir($options[:output])
  else
    Dir.chdir(directory)
  end
  pkz = Bayonetta::PKZFile::load(f)

  pkz.file_descriptors.each { |d|
    f.seek(d.offset)
    File::open(d.name[0..-2], "wb") { |nf|
      nf.write Zstd.decompress(f.read(d.compressed_size))
      raise "Decompression error!" if nf.size != d.size
    }
  }
  Dir.chdir(save_pwd)
  f.close
}
