#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

$layout = YAML::load_file("layout.est")
#$layout = [4]*(1768/4)

def print_layout
  $layout.each { |e|
    case e
    when 4
      print "L"
    when 2
      print "S"
    when 1
      print "C"
    end
  }
  puts
end

def layout_to_mask
  b_mask = ""
  s_mask = ""
  $layout.each { |e|
    if e == 4
      b_mask <<= "L>"
      s_mask <<= "L<"
    elsif e == 2
      b_mask <<= "S>"
      s_mask <<= "S<"
    else
      b_mask <<= "C"
      s_mask <<= "C"
    end
  }
  return [b_mask, s_mask]
end

def update_layout(fb, fs)

  raise "Size differ!" if fb.size != fs.size

  idb = fb.read(4)
  ids = fs.read(4)

  raise "Incorrect file type" if idb != ids || idb != "EST\0".b


  record_number = fs.read(4).unpack("L<").first

  record_offsets = record_number.times.collect {
    fs.read(8).unpack("L<2").last
  }

  record_number.times { |i|
    fs.seek(record_offsets[i])
    datum_number = fs.read(4).unpack("L<").first
    next unless datum_number > 0
    offsets = datum_number.times.collect {
      fs.read(4).unpack("L<").last
    }
    offsets.each_with_index { |offset, k|
      b_mask, s_mask = layout_to_mask
      fs.seek( record_offsets[i] + offset )
      fb.seek( record_offsets[i] + offset )
      s = fs.read(1768).unpack(s_mask)
      b = fb.read(1768).unpack(b_mask)
      new_layout = []
      $layout.length.times { |j|
        if b[j] == s[j] then
          new_layout.push $layout[j]
        elsif  $layout[j] == 1
          raise "Error different data!!!"
        else
          new_layout.push $layout[j]/2
          new_layout.push $layout[j]/2
        end
      }
      raise "Invalid layout!" if new_layout.reduce(:+) != 1768
      $layout = new_layout
    }
  }
end


old_layout = $layout

if File::directory?(ARGV[0]) && File::directory?(ARGV[1])
  entries_big = Dir.entries(ARGV[0]).select { |e| File::file?("#{ARGV[0]}/#{e}") && File.extname(e) == ".dat" }
  entries_small = Dir.entries(ARGV[1]).select { |e| File::file?("#{ARGV[1]}/#{e}") && File.extname(e) == ".dat" }

  entries = entries_big & entries_small

  entries.each { |e|
    big_f = File::new("#{ARGV[0]}/#{e}", "rb")
    small_f = File::new("#{ARGV[1]}/#{e}", "rb")
    big_dat = Bayonetta::DATFile::load(big_f)
    small_dat = Bayonetta::DATFile::load(small_f)
    big_eff_list = big_dat.each.collect.select { |name, df|
      File.extname(name) == ".eff"
    }
    big_eff_list.sort { |e1, e2| e1[0] <=> e2[0] }
    small_eff_list = small_dat.each.collect.select { |name, df|
      File.extname(name) == ".eff"
    }
    small_eff_list.sort { |e1, e2| e1[0] <=> e2[0] }

    big_eff_list.length.times { |i|
      big_eff = Bayonetta::EFFFile::new(big_eff_list[i][1], true)
      small_eff = Bayonetta::EFFFile::new(small_eff_list[i][1], false)
      est_big = big_eff.each_directory.collect.select { |info, ef|
        ef.name == "EST"
      }.first[1].each.collect.first[1]
      est_small = small_eff.each_directory.collect.select { |info, ef|
        ef.name == "EST"
      }.first[1].each.collect.first[1]
      update_layout(est_big, est_small)

    }

  }

else
  file_big = ARGV[0]
  file_small = ARGV[1]

  fb = File::new(file_big, "rb")
  fs = File::new(file_small, "rb")

  update_layout(fb, fs)

  fb.close
  fs.close
end

unless old_layout == $layout
  puts "Layout updated!"
  File::open("layout.est", "w") { |f|
    f.write( YAML::dump($layout) )
  }
else
  puts "Same layout!"
end
print_layout
