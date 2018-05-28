#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

vertex_type = Hash::new { |hash, key| hash[key] = [] }
if File.exist?("vertex_type_database.yaml")
  vertex_type.update YAML::load_file("vertex_type_database.yaml")
else
end

wmb_block = lambda { |name, f, fname|
  begin
    f.rewind
    w = Bayonetta::WMBFile::load(f)
  rescue
    warn "could not open #{name} in #{fname}!"
    next
  end
  vertex_type[[w.header.u_b, w.header.vertex_ex_data_size, w.header.vertex_ex_data]].push("#{fname}/#{name}")
}

if File::directory?(ARGV[0])
  dats = Dir.glob("#{ARGV[0]}/**/*.dat")
  dats.each { |path|
    File::open(path, "rb") { |f|
      begin
        d = Bayonetta::DATFile::new(f)
      rescue
        warn "could not open #{path}!"
        next
      end
      wmbs = d.each.collect.select { |name, df|
        File.extname(name) == ".wmb"
      }
      scrs = d.each.collect.select { |name, df|
        File.extname(name) == ".scr"
      }
      wmbs.each { |name, f|
        wmb_block.call(name, f, path)
      }
      scrs.each { |name, sf|
        begin
          scr = Bayonetta::SCRFile::new(sf)
        rescue
          warn "could not open #{name}!"
          next
        end
        scr.each_model.each_with_index { |f, i|
          wmb_block.call(i, f, "#{path}/#{name}")
        }
      }
    }
  }
else
  raise "Invalid directory #{ARGV[0]}!"
end

File::open("vertex_type_database.yaml", "w") { |f|
  f.write YAML::dump( vertex_type )
}
