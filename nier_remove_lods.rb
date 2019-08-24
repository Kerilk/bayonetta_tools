#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

module Bayonetta
  class WMB3FilePartial < DataConverter
    register_field :header, WMB3File::Header
    register_field :lods, WMB3File::Lod, count: 'header\info_lods\number', sequence: true,
                   offset: 'header\info_lods\offset + __iterator * 20'

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      wmb = self::new
      wmb.instance_variable_set(:@__was_big, false)
      wmb.load(input, false)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      wmb
    end

  end

end

wmb_block = lambda { |path, f|
  puts "\tFound #{File::basename(path)}"
  begin
    f.rewind
    w = Bayonetta::WMB3FilePartial::load(f)
  rescue
    warn "could not open #{path}!"
    next
  end
  patched = false
  w.lods.collect(&:name)
  lod0 = w.lods.find { |l| l.name.match(/LOD0/) }
  if lod0
    w.lods.each_with_index { |l, index|
      match = l.name.match(/LOD(\d)/)
      if match && match[1].to_i > 0
        puts "\t\tPatching #{l.name.strip}"
        patched = true
        offset = w.header.info_lods.offset + index * 20 + 8
        f.seek(offset)
        f.write([lod0.header.batch_start,
                 lod0.header.offset_batch_infos,
                 lod0.header.num_batch_infos].pack("L*"))
      end
    }
  end
  patched
}

dat_block = lambda { |path, f|
  puts "Processing #{path}"
  begin
    d = Bayonetta::DATFile::new(f)
  rescue
    warn "could not open #{path}!"
    next
  end
  wmbs = d.each.collect.select { |n, df|
    File.extname(n) == ".wmb" && df.size > 0
  }
  patched = false
  wmbs.each { |n, wf|
    res = wmb_block.call("#{path}/#{n}", wf)
    patched = true if res
  }
  if patched
    dir_path = File::join(File::dirname(path),"dat_output")
    Dir.mkdir(dir_path) unless Dir.exist?(dir_path)
    file_path = File::join(dir_path, File::basename(path))
    puts "\tWriting #{file_path}..."
    d.dump(file_path)
  end
}

path = ARGV[0]
if File::directory?(path)
  dats = Dir.glob("#{ARGV[0]}/**/*.dtt")
  dats.each { |path|
    File::open(path, "rb") { |f|
       dat_block.call(path, f)
    }
  }
elsif File::exist?(path)
  File::open(path, "rb") { |f|
    dat_block.call(path, f)
  }
else
  raise "Invalid file or directory: #{ARGV[0]}!"
end
