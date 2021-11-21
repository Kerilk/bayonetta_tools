require 'fileutils'
require 'optparse'
require 'yaml'
require_relative '../../bayonetta'

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: dat_extractor [dat_file [dat_file2 ...]]
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

  raise "Invalid file: #{filename}!" unless ext_name == ".dat" || ext_name == ".evn" || ext_name == ".eff" || ext_name == ".dtt"

  next unless File::size?(filename)
  f = File::open(filename, "rb")

  if $options[:output]
    Dir.chdir(save_pwd)
    Dir.chdir($options[:output])
  else
    Dir.chdir(directory)
  end
  dir_name = File.basename(name, ext_name) + "#{ext_name.gsub(".","_")}"
  Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
  Dir.chdir(dir_name)

  dat = Bayonetta::DATFile::load(f)

  duplicates = dat.each.each_with_object(Hash.new(0)) { |f, counts|
    name, _ = f
    counts[name] += 1
  }
  duplicates.select! { |name, count| count > 1 }

  if duplicates.size > 0
    puts "Duplicate files found:"
    duplicates.each { |name, count|
      files = dat.each.to_a
      puts "#{name} : #{(idx = files.each_index.select{ |i| files[i][0] == name }).inspect}"
      puts "\t sizes: #{idx.collect { |i| files[i][1].size }.inspect}"
    }
  end

  dat.each { |name, f|
    d = File::dirname(name)
    if d != "."
      FileUtils.mkdir_p(d)
    end
    File::open(name, "wb") { |f2|
      f2.write(f.read)
    }
  }
  Dir.mkdir(".metadata") unless Dir.exist?(".metadata")
  Dir.chdir(".metadata")
  File::open("layout.yaml", "w") { |fl|
    fl.print YAML::dump( dat.layout )
  }
  File::open("extension.yaml", "w") { |fl|
    fl.print YAML::dump( ext_name )
  }
  File::open("big.yaml","w") { |fl|
    fl.print YAML::dump( dat.big )
  }
  if dat.hash_map
    File::open("hash_map.yaml", "w") { |fl|
      fl.print YAML::dump( dat.hash_map.get )
    }
  end
  # clean up
  Dir.chdir(save_pwd)
}
