#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

materials = Hash::new { |hash, key| hash[key] = {} }
if File.exist?("material_database.yaml")
  materials.update YAML::load_file("material_database.yaml")
else
end

wmb_block = lambda { |path, f|
  puts path
  begin
    f.rewind
    w = Bayonetta::WMBFile::load(f)
  rescue
    warn "could not open #{path}!"
    next
  end
  w.materials[0..-2].each { |m|
    if materials.key?(m.type)
      if materials[m.type][:size] == :unknown
        materials[m.type][:size] = m.size
      else
        warn "Incoherent material size #{m.size} != #{materials[m.type][:size]} for #{m.type} in #{path}!" if m.size != materials[m.type][:size]
      end
      materials[m.type][:files].push path
    else
      materials[m.type][:files] = [path]
      materials[m.type][:size] = m.size

    end
  }
  m = w.materials.last
  if materials.key?(m.type)
    materials[m.type][:files].push path
  else
    materials[m.type][:files] = [path]
    materials[m.type][:size] = :unknown
  end
}

dat_block = lambda { |path, f|
  begin
    d = Bayonetta::DATFile::new(f)
  rescue
    warn "could not open #{path}!"
    next
  end
  wmbs = d.each.collect.select { |n, df|
    File.extname(n) == ".wmb" && df.size > 0
  }
  scrs = d.each.collect.select { |n, df|
    File.extname(n) == ".scr" && df.size > 0
  }
  effs = d.each.collect.select { |n, df|
    (File.extname(n) == ".eff" || File.extname(n) == ".idd") && df.size > 0
  }
  wmbs.each { |n, wf|
    wmb_block.call("#{path}/#{n}", wf)
  }
  scrs.each { |n, sf|
    begin
      scr = Bayonetta::SCRFile::new(sf)
    rescue
      warn "could not open #{path}/#{n}!"
      next
    end
    scr.each_model.each_with_index { |wf, i|
      wmb_block.call("#{path}/#{n}/#{i}.wmb", wf)
    }
  }
  effs.each { |n, ef|
    begin
      eff = Bayonetta::EFFFile::new(ef)
    rescue
      warn "could not open #{path}/#{n}!"
      next
    end
    eff.each_directory { |_, d|
      if d.name == "MOD"
        d.each { |dfn, df|
          dat_block.call("#{path}/#{n}/#{d.name}/#{dfn}", df)
        }
      end
    }
  }
}

if File::directory?(ARGV[0])
  dats = Dir.glob("#{ARGV[0]}/**/*.dat")
  dats.each { |path|
    File::open(path, "rb") { |f|
      dat_block.call(path, f)
    }
  }
else
  raise "Invalid directory #{ARGV[0]}!"
end

materials.each { |k, v| v[:files].uniq! }

File::open("material_database.yaml", "w") { |f|
  f.write YAML::dump( materials )
}
