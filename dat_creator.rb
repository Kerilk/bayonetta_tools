input_dir = ARGV[0]

class BayoFile
  attr_reader :name
  attr_reader :base_name
  attr_reader :ext_name
  attr_reader :ext
  attr_reader :size
  attr_reader :f
  def initialize(name)
    @name = name
    @f = File.open(name, "rb")
    @ext_name = File.extname(@name)
    @base_name = File.basename(@name, @ext_name)
    @ext = @ext_name[1..-1]
    @size = @f.size
  end
end

def align(val, alignment)
  remainder = val % alignment
  val += alignment - remainder if remainder > 0
  val
end

class FileLayout
  attr_reader :layout
  ALIGNMENTS = {
    '.wmb' => 0x1000,
    '.wtb' => 0x1000,
    '.exp' => 0x1000,
    '.eff' => 0x1000,
    '.sdx' => 0x1000
  }
  ALIGNMENTS.default = 0x10

  def initialize(files)
    @files = files
    @files.sort! { |f1, f2| ALIGNMENTS[f2.ext_name] <=> ALIGNMENTS[f1.ext_name] }
    
    @layout = {
      :id => 0x0,
      :file_number => 0x4,
      :file_starts_offset => 0x8,
      :file_extensions_offset => 0xc,
      :file_names_offset => 0x10,
      :file_sizes_offset => 0x14,
    }
    @id = "DAT\0"
    @file_number = @files.length
    @file_starts_offset = 0x20
    @file_extensions_offset = @file_starts_offset + 4 * @file_number
    @file_names_offset = @file_extensions_offset + 4 * @file_number
    max_file_name_length = @files.collect(&:name).collect(&:length).max
    @file_name_length = max_file_name_length + 1
    @file_sizes_offset = @file_names_offset + 4 + @file_name_length * @file_number
    @file_sizes_offset = align(@file_sizes_offset, 4)
    files_offset = @file_sizes_offset + 4 * @file_number
    @files_offsets = @files.collect { |f|
      tmp = align(files_offset, ALIGNMENTS[f.ext_name])
      files_offset = align(tmp + f.size, ALIGNMENTS[f.ext_name])
      tmp
    }
    @total_size = align(files_offset, 0x1000)
  end

  def dump(name)
    File.open(name,"wb") { |f|
      f.write("\0"*@total_size)
      f.seek(0)
      f.write([@id].pack("a4"))
      f.write([@file_number].pack("L"))
      f.write([@file_starts_offset].pack("L"))
      f.write([@file_extensions_offset].pack("L"))
      f.write([@file_names_offset].pack("L"))
      f.write([@file_sizes_offset].pack("L"))

      f.seek(@file_starts_offset)
      f.write(@files_offsets.pack("L*"))

      f.seek(@file_extensions_offset)
      @files.each { |bf|
        f.write([bf.ext].pack("a4"))
      }

      f.seek(@file_names_offset)
      f.write([@file_name_length].pack("L"))
      @files.each { |bf|
        f.write([bf.name].pack("a#{@file_name_length}"))
      }

      f.seek(@file_sizes_offset)
      f.write(@files.collect(&:size).pack("L*"))

      @files_offsets.each_with_index { |off, i|
        f.seek(off)
	f.write( @files[i].f.read )
      }
    }
  end

end

files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) }
Dir.mkdir("dat_output") unless Dir.exist?("dat_output")
files.collect! { |fname| BayoFile::new(fname) }

fl = FileLayout::new(files)
fl.dump("dat_output/#{File.basename(ARGV[0])}.dat")

