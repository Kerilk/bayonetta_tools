require 'optparse'
require 'fileutils'
require 'zstd-ruby'
require 'oodle-kraken-ruby'
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
    fname = d.name[0..-2]
    compression = d.compression[0..-2]
    dirname = File.dirname(fname)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
    case compression
    when "ZStandard"
      File::open(fname, "wb") { |nf|
        nf.write Zstd.decompress(f.read(d.compressed_size))
        raise "Decompression error!" if nf.size != d.size
      }
    when "OodleKraken"
      File::open(fname, "wb") { |nf|
        nf.write OodleKraken.decompress(f.read(d.compressed_size), d.size)
      }
    when "None"
      File::open(fname, "wb") { |nf|
        nf.write f.read(d.compressed_size)
      }
    else
      warn "Unsupported compression format for #{fname}: #{compression}!"
    end
  }
  Dir.chdir(save_pwd)
  f.close
}
