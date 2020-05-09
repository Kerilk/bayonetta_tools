require 'stringio'
module Bayonetta
  class DATFile < LibBin::DataConverter
    attr_reader :big
    ALIGNMENTS = {
      'wmb' => 0x1000,
      'wtb' => 0x1000,
      'wtp' => 0x1000,
      'wta' =>   0x40,
      'exp' => 0x1000,
      'sop' =>   0x40,
      'eff' => 0x1000,
      'sdx' => 0x1000,
      'bxm' =>   0x40
    }
    ALIGNMENTS.default = 0x10

    class Header < LibBin::DataConverter
      string :id, 4
      uint32 :num_files
      uint32 :offset_file_offsets
      uint32 :offset_file_extensions
      uint32 :offset_file_names
      uint32 :offset_file_sizes
      uint32 :offset_hash_map
    end

    class HashMap < LibBin::DataConverter
      class Header < LibBin::DataConverter
        uint32 :pre_hash_shift
        uint32 :offset_bucket_ranks
        uint32 :offset_hashes
        uint32 :offset_file_indices
      end
      register_field :header, Header
      int16 :bucket_ranks, count: '(1<<(31 - header\pre_hash_shift))', offset: 'header\offset_bucket_ranks', relative_offset: true
      uint32 :hashes, count: '..\header\num_files', offset: 'header\offset_hashes', relative_offset: true
      uint16 :file_indices, count: '..\header\num_files', offset: 'header\offset_file_indices', relative_offset: true

      def get
        {
          pre_hash_shift: @header.pre_hash_shift,
          hashes: file_indices.zip(hashes).sort { |(i1 ,h1), (i2, h2)|
            i1 <=> i2
          }.collect { |i, h|
            h
          }
        }
      end

      def initialize
        super
        @header = Header::new
      end

      def set(hash_map)
        bit_shift = hash_map[:pre_hash_shift]
        hash_list = hash_map[:hashes]
        num_files = hash_list.size
        @header.pre_hash_shift = bit_shift
        buckets = Hash::new { |h, k| h[k] = [] }
        hash_list.each_with_index { |h, i|
          bucket_index = h >> @header.pre_hash_shift
          buckets[bucket_index].push [h, i]
        }
        @bucket_ranks = []
        @hashes = []
        @file_indices = []
        bucket_rank = 0
        num_buckets = (1 << (31 - header.pre_hash_shift))
        num_buckets.times { |i|
          if buckets.has_key?(i)
            @bucket_ranks.push bucket_rank
            bucket_rank += buckets[i].size
            buckets[i].each { |h, ind|
              @hashes.push h
              @file_indices.push ind
            }
          else
            @bucket_ranks.push -1
          end
        }
        @header.offset_bucket_ranks = 0x10
        @header.offset_hashes = header.offset_bucket_ranks + num_buckets * 2
        @header.offset_file_indices = header.offset_hashes + num_files * 4
        self
      end
    end

    register_field :header, Header
    uint32 :file_offsets, count: 'header\num_files', offset: 'header\offset_file_offsets'
    string :file_extensions, 4, count: 'header\num_files', offset: 'header\offset_file_extensions'
    uint32 :file_name_length, offset: 'header\offset_file_names'
    string :file_names, count: 'header\num_files', offset: 'header\offset_file_names + 4 + __iterator * file_name_length', sequence: true
    uint32 :file_sizes, count: 'header\num_files', offset: 'header\offset_file_sizes'
    register_field :hash_map, HashMap, offset: 'header\offset_hash_map'
    string :files, 'file_sizes[__iterator]', count: 'header\num_files', offset: 'file_offsets[__iterator]', sequence: true

    def self.is_big?(f)
      f.rewind
      block = lambda { |big|
        h = Header::load(f, big)
        h.offset_file_offsets < f.size &&
          h.offset_file_names < f.size &&
          h.offset_file_sizes < f.size &&
          h.offset_hash_map < f.size
      }
      big = block.call(true)
      f.rewind
      small = block.call(false)
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def initialize(big = false)
      @big = big
      super()
      @header = Header::new
      @header.id = "DAT\x00".b
      @header.num_files = 0
      @header.offset_file_offsets = 0
      @header.offset_file_extensions = 0
      @header.offset_file_names = 0
      @header.offset_file_sizes = 0
      @header.offset_hash_map = 0

      @file_offsets = []
      @file_extensions = []
      @file_name_length = 0
      @file_names = []
      @file_sizes = []
      @files = []

      @hash_map = nil
    end

    def invalidate_layout
      @header.offset_file_offsets = 0
      @header.offset_file_extensions = 0
      @header.offset_file_names = 0
      @header.offset_file_sizes = 0
      @header.offset_hash_map = 0
      @file_offsets = []
      @hash_map = nil
      self
    end

    def layout
      @file_names.collect { |name| name[0..-2] }
    end

    def each
      if block_given? then
        @header.num_files.times { |i|
          yield @file_names[i][0..-2], StringIO::new(@files[i] ? @files[i] : "", "rb")
        }
      else
        to_enum(:each)
      end
    end

    def [](i)
      return [@file_names[i][0..-2], StringIO::new(@files[i] ? @files[i] : "", "rb")]
    end

    def push(name, file)
      invalidate_layout
      @file_names.push name+"\x00"
      if file.kind_of?(StringIO)
        data = file.string
      else
        file.rewind
        data = file.read
      end
      @files.push data
      @file_sizes.push file.size
      extname = File.extname(name)
      raise "Invalid name, missing extension!" if extname == ""
      @file_extensions.push extname[1..-1]+"\x00"
      @header.num_files += 1
      self
    end

    def compute_layout
      @header.offset_file_offsets = 0x20
      @header.offset_file_extensions = @header.offset_file_offsets + 4 * @header.num_files
      @header.offset_file_names = @header.offset_file_extensions + 4 * @header.num_files
      max_file_name_length = @file_names.collect(&:length).max
      @file_name_length = max_file_name_length
      @header.offset_file_sizes = @header.offset_file_names + 4 + @file_name_length * @header.num_files
      @header.offset_file_sizes = align(@header.offset_file_sizes, 4)
      if @hash_map
        @header.offset_hash_map = @header.offset_file_sizes + 4 * @header.num_files
        files_offset = @header.offset_hash_map + @hash_map.__size(@header.offset_hash_map, self)
      else
        @offset_hash_map = 0
        files_offset = @header.offset_file_sizes + 4 * @header.num_files
      end
      @file_offsets = @header.num_files.times.collect { |i|
        if @file_sizes[i] > 0
          tmp = align(files_offset, ALIGNMENTS[@file_extensions[i][0..-2]])
          files_offset = align(tmp + @file_sizes[i], ALIGNMENTS[@file_extensions[i][0..-2]])
          tmp
        else
          0
        end
      }
      @total_size = align(files_offset, 0x1000)
      self
    end

    def set_hash_map(hash)
      @hash_map = HashMap::new
      @hash_map.set hash
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        File.open(input_name, "rb") { |f|
          input = StringIO::new(f.read, "rb")
        }
      end
      big = self::is_big?(input)
      dat = self::new(big)
      dat.__load(input, big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      dat
    end

    def dump(output_name)
      compute_layout
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = StringIO::new("", "wb")#File.open(output_name, "wb")
        output.write("\x00"*@total_size)
        output.rewind
      end
      output.rewind

      __set_dump_type(output, @big, nil, nil)
      __dump_fields
      __unset_dump_type

      unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        File.open(output_name, "wb") { |f|
          f.write output.string
        }
        output.close
      end
      self
    end

  end

end
