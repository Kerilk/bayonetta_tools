filename = ARGV[0]
directory = File.dirname(filename)
name = File.basename(filename)
ext_name = File.extname(name)

raise "Invalid file (#{name})!" unless ext_name == ".dat"


f = File::open(filename, "rb")

Dir.chdir(directory)
dir_name = File.basename(name, ext_name)
Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
Dir.chdir(dir_name)

id = f.read(4).unpack("a4").first

raise "Invalid id #{id.inspect}!" if id != "DAT\0"

file_number = f.read(4).unpack("L").first
puts "Found #{file_number} files!"


file_starts_offset = f.read(4).unpack("L").first
file_extensions_offset = f.read(4).unpack("L").first
file_names_offset = f.read(4).unpack("L").first
file_sizes_offset = f.read(4).unpack("L").first

f.seek(file_starts_offset)
file_offsets = f.read(4*file_number).unpack("L*")

f.seek(file_names_offset)
filename_length = f.read(4).unpack("L").first
file_names = file_number.times.collect {
	f.read(filename_length).unpack("a#{filename_length}").first.delete("\0")
}

f.seek(file_sizes_offset)
file_sizes = f.read(4*file_number).unpack("L*")

if  file_number > file_names.uniq.length
  puts "Duplicate files found:"
  duplicates = file_names.each_with_object(Hash.new(0)) { |name, counts| counts[name] += 1 }.select { |name,count| count > 1 }
  duplicates.each { |name, count|
    puts "#{name} : #{(idx = file_names.each_index.select{ |i| file_names[i] == name }).inspect}"
    puts "\t sizes: #{idx.collect { |i| file_sizes[i] }.inspect}"
    #p idx.collect { |i| file_offsets[i] }
  }
end

files = file_names.zip(file_offsets, file_sizes)

files.each { |name, offset, size|
  File::open(name, "wb") { |of|
    f.seek(offset)
    of.write(f.read(size))
  }
}

#    max_file_name_length = @files.collect(&:name).collect(&:length).max
#    @file_name_length = max_file_name_length + 1
#    @file_sizes_offset = @file_names_offset + 4 + @file_name_length * @file_number
#    @file_sizes_offset = align(@file_sizes_offset, 4)
#    files_offset = @file_sizes_offset + 4 * @file_number
 
