require 'win32-mmap'
require 'float-formats'

include Win32

Flt::IEEE.binary :IEEE_binary16_pg, significand: 9, exponent: 6, bias: 47

class MotHeader < FFI::Struct
  layout :id,           [:char, 4],
         :flag,          :short,
         :frame_count,   :short,
         :motion_offset, :int,
         :num_entries,   :int
  def to_s
    puts "#{self[:id]}: flag: #{self[:flag]}, frame count: #{self[:frame_count]}, num entries: #{self[:num_entries]}, (motion offset: #{self[:motion_offset]})"
  end
end

class HalfFloat < FFI::Struct
  layout :value, [:char, 2]

  def to_s
    value.to_s
  end

  def value=(new)
    s = Flt::IEEE_binary16_pg::new(new).to_bytes.bytes
    self[:value][0] = s[0]
    self[:value][1] = s[1]
  end

  def value
    Flt::IEEE_binary16_pg::from_bytes(self[:value].to_ptr.read_string(2)).to(Float)
  end

end

class MotionField < FFI::Union
  layout :float,  :float,
         :offset, :int
end

class InterpolationHeader4 < FFI::Struct
  layout :values, [:float, 6]

  def to_s
    return self[:values].collect.to_a.join(", ")
  end

end

class InterpolationItem4 < FFI::Struct
  layout :frame_index, :short,
         :values, [:ushort, 3]

  def to_s
    return "#{self[:frame_index]}: " + self[:values].collect.to_a.join(", ")
  end

end

class InterpolationHeader6 < FFI::Struct
  layout :values, [HalfFloat, 6]

  def to_s
    return self[:values].collect.to_a.join(", ")
  end

end

class InterpolationItem6 < FFI::Struct
  layout :frame_delta, :uchar,
         :values, [:uchar, 3]

  def to_s
    return "#{self[:frame_delta]}: " + self[:values].collect.to_a.join(", ")
  end

end

class InterpolationHeader7 < FFI::Struct
  layout :values, [HalfFloat, 6]

  def to_s
    return self[:values].collect.to_a.join(", ")
  end

end

class InterpolationItem7 < FFI::Struct
  layout :frame_index, :short,
	 :dummy, :uchar,
         :values, [:uchar, 3]

  def to_s
    return "#{self[:frame_index]}: " + self[:values].collect.to_a.join(", ") + " (dummy: #{self[:dummy]})"
  end

end

class MotionItem < FFI::Struct
  layout :bone_index,  :short,
         :index,       :char,
         :flag,        :uchar,
         :elem_number, :short,
	 :unknown,     :short,
         :value,       MotionField

  def to_s
    s = "#{self[:bone_index]} : index: #{self[:index]}, flag: #{self[:flag]}, elem_number: #{self[:elem_number]}, unknown: #{self[:unknown]}, "
    case self[:flag]
    when 0, 255
      s += "value: #{self[:value][:float]}"
    else
      s += "offset: #{self[:value][:offset]}\n"
      s += @value.to_s
    end
  end

  def value
    case self[:flag]
    when 0, -1
      return self[:value][:float]
    when 1, 6, 4, 7
      return @value
    else
      raise "Unsupported type! #{self[:flag]}"
    end
  end

  def load_values(base_address)
    case self[:flag]
    when 0, 255
    when 1
      elem_number = self[:elem_number]
	@value = Class::new(FFI::Struct) do
        layout :values, [:float, elem_number]
	def to_s
          s = "\n\t"
	  vals = self[:values].collect.to_a
	  s += vals.each_with_index.collect { |v,i| "#{i} #{v}" }.to_a.join("\n\t")
	end
      end.new(FFI::Pointer::new(base_address + self[:value][:offset]))
    when 4
      elem_number = self[:elem_number]
      @value = Class::new(FFI::Struct) do
        layout :header, InterpolationHeader4,
               :values, [InterpolationItem4, elem_number]
	def to_s
          s = "\t" + self[:header].to_s + "\n\t"
	  s += self[:values].collect.to_a.join("\n\t")
	end
      end.new(FFI::Pointer::new(base_address + self[:value][:offset]))
    when 6
      elem_number = self[:elem_number]
      @value = Class::new(FFI::Struct) do
        layout :header, InterpolationHeader6,
               :values, [InterpolationItem6, elem_number]
	def to_s
          s = "\t" + self[:header].to_s + "\n\t"
	  s += self[:values].collect.to_a.join("\n\t")
	end
      end.new(FFI::Pointer::new(base_address + self[:value][:offset]))
    when 7
      elem_number = self[:elem_number]
      @value = Class::new(FFI::Struct) do
        layout :header, InterpolationHeader7,
               :values, [InterpolationItem7, elem_number]
	def to_s
          s = "\t" + self[:header].to_s + "\n\t"
	  s += self[:values].collect.to_a.join("\n\t")
	end
      end.new(FFI::Pointer::new(base_address + self[:value][:offset]))
   else
      raise "Unsupported type! #{self[:flag]}"
    end
    return self
  end

end

class DatHeader < FFI::Struct
  layout :id,                    [:char, 4],
         :file_number,            :int,
         :file_starts_offset,     :int,
         :file_extensions_offset, :int,
         :file_names_offset,      :int,
         :file_sizes_offset,      :int
end

filename = ARGV[0]
ext_name = File.extname(filename)

raise "Invalid file (#{name})!" unless ext_name == ".mot" || ext_name == ".dat"

map = MMap.new(:file => ARGV[0])

case map.read_string(4)
when "mot\0"
  map_address = map.address
when "DAT\0"
  filename = ARGV[1]
  ext_name = File.extname(filename)
  raise "Invalid file (#{filename})!" unless ext_name == ".mot"

  dat_address = map.address
  dat_header = DatHeader::new(FFI::Pointer::new(dat_address))

  file_number = dat_header[:file_number]
  file_names_offset = dat_header[:file_names_offset]
  file_name_length = FFI::Pointer::new(dat_address + file_names_offset).read_int
  file_names_ptr = FFI::Pointer::new(dat_address + file_names_offset + 4)
  file_names = file_number.times.collect { |i|
    file_names_ptr.get_string(file_name_length*i, file_name_length).delete("\0")
  }
  i = file_names.index(ARGV[1])
  raise "Could not find #{ARGV[1]} in #{ARGV[0]}!" unless i
  file_starts_ptr = FFI::Pointer::new(dat_address + dat_header[:file_starts_offset])
  map_address = dat_address + file_starts_ptr.get_int(4*i)
else
  raise "Invalid file!" unless map.read_string(4) == "mot\0"
end

header = MotHeader::new(FFI::Pointer::new(map_address))
puts header

base_address = map_address + header[:motion_offset]
motion_items = header[:num_entries].times.collect { |i|
  m = MotionItem::new(FFI::Pointer::new(base_address + i * MotionItem.size)).load_values(map_address)
}

motion_items.each { |it|
  puts it
}

#puts motion_items.find_index { |e| e[:bone_index] == 21 && e[:index] == 3 }

#puts motion_items[72][:index]
#puts motion_items[73][:index]
#puts motion_items[74][:index]
#motion_items[72][:index] = 7 #3
#motion_items[73][:index] = 8 #4
#motion_items[74][:index] = 9 #5
#puts motion_items[72].value[:header][:values][0]
#puts motion_items[73][:value][:float]
#puts motion_items[74][:value][:float]
#motion_items[72].value[:header][:values][0].value = 1.0 #0.1552734375
#motion_items[73][:value][:float] = 1.0 #-3.4906582868643454e-07
#motion_items[74][:value][:float] = 2.0 #2.3736477032798575e-06


#puts motion_items[6][:index]
#puts motion_items[7][:index]
#puts motion_items[8][:index]
#motion_items[6][:index] = 7 #3
#motion_items[7][:index] = 8 #4
#motion_items[8][:index] = 9 #5
#puts motion_items[6].value[:header][:values][0]
#puts motion_items[7].value[:header][:values][0]
#puts motion_items[8].value[:header][:values][0]
#motion_items[6].value[:header][:values][0].value = 1.0
#motion_items[7].value[:header][:values][0].value = 1.0
#motion_items[8].value[:header][:values][0].value = 1.0
#
#
#puts motion_items[117][:index]
#puts motion_items[118][:index]
#puts motion_items[119][:index]
#motion_items[117][:index] = 7 #3
#motion_items[118][:index] = 8 #4
#motion_items[119][:index] = 9 #5
#puts motion_items[117].value[:header][:values][0]
#puts motion_items[118].value[:header][:values][0]
#puts motion_items[119].value[:header][:values][0]
#motion_items[117].value[:header][:values][0].value = 1.0
#motion_items[118].value[:header][:values][0].value = 1.0
#motion_items[119].value[:header][:values][0].value = 1.0
#
#
#puts motion_items[107][:index]
#motion_items[107][:index] = 5
#puts motion_items[107].value[:header][:values][0]
#motion_items[107].value[:header][:values][0].value = 0.0
#
#
#
#puts motion_items[60][:index]
#puts motion_items[61][:index]
#puts motion_items[62][:index]
#motion_items[60][:index] = 3
#motion_items[61][:index] = 4
#motion_items[62][:index] = 5
#puts motion_items[60].value[:header][:values][0]
#puts motion_items[61].value[:header][:values][0]
#puts motion_items[62].value[:header][:values][0]
#motion_items[60].value[:header][:values][0].value = -2.0625
#motion_items[61].value[:header][:values][0].value = 0.0
#motion_items[62].value[:header][:values][0].value = 0.0
#

#puts motion_items[7].value[:header][:values][0]
#motion_items[7].value[:header][:values][0].value = 0#Math::sqrt(2*Math::PI/64) * 256#62.73
#puts motion_items[7].value[:header][:values][0]
#puts motion_items[8].value[:header][:values][0]
#motion_items[8].value[:header][:values][0].value = 0#Math::sqrt(2*Math::PI/64) * 256#62.73
#puts motion_items[8].value[:header][:values][0]
#puts motion_items[7].value[:header][:values][2]
#motion_items[7].value[:header][:values][2].value = 0#-255*4#62.73
#puts motion_items[7].value[:header][:values][2]
#puts motion_items[7].value[:header][:values][3]
#motion_items[7].value[:header][:values][3].value = 0#16*4#62.73
#puts motion_items[7].value[:header][:values][3]
#puts motion_items[7].value[:header][:values][4]
#motion_items[7].value[:header][:values][4].value = 0#62.73
#puts motion_items[7].value[:header][:values][4]
#puts motion_items[7].value[:header][:values][5]
#motion_items[7].value[:header][:values][5].value = 0#62.73
#puts motion_items[7].value[:header][:values][5]
#puts motion_items[7].value[:values][0][:values][1]
#motion_items[7].value[:values][0][:values][1] = 0
#puts motion_items[7].value[:values][0][:values][1]
#puts motion_items[7].value[:values][1][:values][1]
#motion_items[7].value[:values][1][:values][1] = 0
#puts motion_items[7].value[:values][1][:values][1]
