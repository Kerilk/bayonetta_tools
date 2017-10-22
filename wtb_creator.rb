input_dir = ARGV[0]

class BayoTex
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
    '.dds' => 0x1000,
  }
  ALIGNMENTS.default = 0x10

  def initialize(files)
    @files = files
    
    @layout = {
      :id => 0x0,
      :unknown => 0x4,
      :num_tex => 0x8,
      :offset_texture_offsets => 0xc,
      :offset_texture_sizes => 0x10,
      :offset_texture_flags => 0x14,
      :offset_texture_idx => 0x18,
      :offset_texture_info => 0x1c
    }
    @id = "WTB\0"
    @unknown = 0x0
    @num_tex = @files.length
    @offset_texture_offsets = 0x20
    @offset_texture_sizes = align(@offset_texture_offsets + 4*@num_tex, 0x10)
    @offset_texture_flags = align(@offset_texture_sizes + 4*@num_tex, 0x10)
    @offset_texture_idx = 0x0
    @offset_texture_info = 0x0

    @texture_sizes = @files.collect { |f| f.size }
    @texture_flags = [0x0]*@num_tex
    file_offset = @offset_texture_flags + 4*@num_tex
    @texture_offsets = @files.collect { |f|
      tmp = align(file_offset, ALIGNMENTS[f.ext_name])
      file_offset = align(tmp + f.size, ALIGNMENTS[f.ext_name])
      tmp
    }
    @total_size = align(file_offset, 0x1000)
  end

  def dump(name)
    File.open(name,"wb") { |f|
      f.write("\0"*@total_size)
      f.seek(0)
      f.write([@id].pack("a4"))
      f.write([@unknown].pack("L"))
      f.write([@num_tex].pack("L"))
      f.write([@offset_texture_offsets].pack("L"))
      f.write([@offset_texture_sizes].pack("L"))
      f.write([@offset_texture_flags].pack("L"))
      f.write([@offset_texture_idx].pack("L"))
      f.write([@offset_texture_info].pack("L"))

      f.seek(@offset_texture_offsets)
      f.write(@texture_offsets.pack("L*"))

      f.seek(@offset_texture_sizes)
      f.write(@texture_sizes.pack("L*"))

      f.seek(@offset_texture_flags)
      f.write(@texture_flags.pack("L*"))

      @texture_offsets.each_with_index { |off, i|
        f.seek(off)
	f.write( @files[i].f.read )
      }
    }
  end

end


files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) && File.extname(f) == ".dds" }
files.sort!
puts files
Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
files.collect! { |fname| BayoTex::new(fname) }

fl = FileLayout::new(files)
fl.dump("wtb_output/#{File.basename(ARGV[0])}.wtb")

