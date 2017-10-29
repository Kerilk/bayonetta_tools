filename = ARGV[0]
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)

raise "Invalid file (#{name})!" unless ext_name == ".eff"

f = File::open(filename, "rb")

Dir.chdir(directory)
dir_name = File.basename(name, ext_name)+"_eff"
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

id = f.read(4).unpack("a4").first
raise "Invalid id #{id.inspect}!" if id != "EF2\0"

directory_number = f.read(4).unpack("L<").first
puts "Found #{directory_number} directories."
directory_info = directory_number.times.collect {
  f.read(8).unpack("L<2")
}
directory_info.each_with_index { |info, i|
  id, offset = info
  f.seek(offset)
  dir_name = f.read(4).unpack("a4").first
  d_name = ("%02d_"%id) + dir_name.delete("\0")
  Dir.mkdir(d_name) unless Dir.exist?(d_name)
  puts d_name
  if dir_name == "EST\0"
    File::open("#{d_name}/data.est", "wb") { |f2|
      if directory_info[i+1] then
        size = directory_info[i+1][1] - offset
      else
        size = f.size - offset
      end
      f.seek(offset)
      f2.write(f.read(size))
    }
    next
  end
  file_number = f.read(4).unpack("L<").first
  puts "\tfound #{file_number} files."
  p file_info = file_number.times.collect {
    f.read(8).unpack("L<2")
  }
  file_info.each_with_index { |finfo, j|
    fid, foffset = finfo
    a_offset = offset + foffset
    size = 0
    if file_info[j+1]
      size = file_info[j+1][1] - foffset
    elsif directory_info[i+1]
      size = directory_info[i+1][1] - a_offset
    else
      size = f.size - a_offset
    end
    f.seek( a_offset )
    f_ext = f.read(4).unpack("a4").first
    f.seek( a_offset )
    File::open("#{d_name}/%010d."%fid+f_ext.delete("\0").downcase, "wb") { |f2|
      f2.write(f.read(size))
    }

  }
}
f.close
