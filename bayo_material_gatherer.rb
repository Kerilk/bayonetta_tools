#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

materials = Hash::new { |hash, key| hash[key] = {} }
if File.exist?("material_database.yaml")
  materials.update YAML::load_file("material_database.yaml")
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
  w.materials[0..-2].each { |m|
    if materials.key?(m.type)
      warn "Incoherent material size #{m.size} != #{materials[m.type][:size]} for #{m.type} in #{name}!" if m.size != materials[m.type][:size]
    else
      materials[m.type][:size] = m.size
    end
  }
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

File::open("material_database.yaml", "w") { |f|
  f.write YAML::dump( materials )
}
