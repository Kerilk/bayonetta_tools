require 'set'
require 'optparse'

$wa = false
$cmode = false
$indent = 0
$pointer_size = 4

parser = OptionParser.new do |opts|
  opts.banner = "Usage: pdb.rb target_file [options]"

  opts.on("--[no-]workaround", "Activate workaround for off by one bug") do |wa|
    $wa = wa
  end

  opts.on("--[no-]c-output", "Activate c output mode") do |c|
    $cmode = c
  end

  opts.on("-p", "--pointer-size SIZE", Integer, "Size in byte of pointers, default 4") do |sz|
    $pointer_size = sz
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end
parser.parse!

input_file = ARGV[0]
raise "Invalid file #{input_file}" unless File::file?(input_file)

pdb = File.read(input_file).tr("\r","")

if $wa
  # Patch table due to off by one offset due to multiple page
  lines = pdb.lines
  missing_value = "0x0001D87B"
  linebeg = 544360
  lineend = 544927
  new_pdb = lines[0...linebeg]
  new_pdb += lines[linebeg...lineend].map { |l|
    match = l.match(/index = ([^,]+)/)
    if match
      l = l.sub(match[1], "#{missing_value}")
      missing_value = match[1]
    else
      match = l.match(/list = ([^,]+)/)
      if match
        l = l.sub(match[1], "#{missing_value}")
        missing_value = match[1]
      end
    end
    l
  }
  new_pdb += lines[lineend..-1]
  pdb = new_pdb.join
end

def opn
  pr "{"
  $indent += 1
end

def cls(t = true)
  $indent -= 1
  s = "}"
  s << ";" if t
  pr s
end

def indent(v)
  ("\t" * $indent) << v
end

def pr(*args)
  puts args.map { |l| indent(l) }.join("\n")
end

class EnumValue
  attr_reader :name, :value
  def initialize(name, value)
    @name, @value = name, value
  end

  def to_s
    "#{name} = 0x%x" % (value < 0 ? [value].pack('i').unpack('I') : value)
  end
end

class Enum
  attr_reader :name
  attr_accessor :values, :type
  def initialize(name, type, values)
    @name, @type, @values = name, type, values
  end

  def to_s(n = nil)
    str = "#{name}"
    str << " #{n}" if n
    str
  end

  def print
    pr "enum #{@name}#{@type ? " /* #{type} */" : ""}"
    opn
    @values.each { |v| pr v.to_s << "," } if @values
    cls
  end

  def size
    @type.size
  end
end

class BitfieldValue
  attr_reader :bits, :start, :type
  def initialize(bits, start, type)
    @bits, @start, @type = bits, start, type
  end

  def to_s(name)
    "#{@type.to_s(name)} : #{@bits}#{@start ? " /* start #{@start} */" : "" }"
  end
end

class Member
  attr_reader :name, :type, :offset, :visibility
  def initialize(name, type, offset, visibility)
    @name, @type, @offset, @visibility = name, type, offset, visibility
  end

  def to_s
    @type.to_s(name) << " /* #{visibility} */"
  end
end

class StaticMember
  attr_reader :name, :type, :visibility
  def initialize(name, type, visibility)
    @name, @type, @visibility = name, type, visibility
  end

  def to_s
    "static " << @type.to_s(name) << " /* #{visibility} */"
  end
end

class Procedure
  attr_reader :return_type, :args
  def initialize(return_type, args)
    @return_type, @args = return_type, args
  end

  def to_s(name = nil)
    frame_args = $frames[[name, self]]
    if (frame_args)
      arg_names = frame_args.map { |_, n, _| n } 
    else
      arg_names = nil
    end
    str = ""
    if @args
      if @args.empty?
        str << "void"
      else
        if arg_names
          @args.each_with_index { |a, i|
            if a == BaseType::NOTYPE # varargs
              arg_names[i] = "..."
            else
              if frame_args[i] && a != frame_args[i][0]
                arg_names.insert(i, nil)
              end
            end
          }
          str << @args.zip(arg_names).map { |a, n| a.to_s(n) }.join(", ")
        else
          str << @args.join(", ")
        end
      end
    end
    str = "#{name}(#{str})"
    if @return_type
      @return_type.to_s(str)
    else
      str
    end
  end
end

class MFunction
  attr_reader :return_type, :args, :class_type, :this_type
  def initialize(return_type, args, class_type, this_type)
    @return_type, @args, @class_type, @this_type = return_type, args, class_type, this_type
  end

  def to_s(name = nil)
    scoped_name = "#{@class_type.name}::#{name}"
    frame_args = $frames[[scoped_name, self]]
    if (frame_args)
      if @this_type
        if frame_args.first && frame_args.first[1] == "this"
          raise "Error invalid class type #{scoped_name}" if frame_args.first[0] != @this_type
          frame_args = frame_args[1..-1] unless $cmode
        end
      end
      arg_names = frame_args.map { |_, n, _| n }
    else
      #$stderr.puts "Warning #{scoped_name} missing frame!"
      #$stderr.puts "Warning a similarly named frame exists!" if $frame_names.include? scoped_name
      arg_names = nil
    end
    str = ""
    args2 = []
    args2 << @this_type if @this_type && $cmode
    args2 += @args if @args
    if args2.empty?
      str << "void"
    else
      if arg_names
        args2.each_with_index { |a, i|
          if a == BaseType::NOTYPE # varargs
            arg_names[i] = "..."
          else
            if frame_args[i] && a != frame_args[i][0]
              arg_names.insert(i, nil) #unused and optimized away when inlining
            end
            # most probably unused
            #$stderr.puts "Warning #{i} #{scoped_name} #{a.class} no args"  unless frame_args[i]
          end
        }
        str << args2.zip(arg_names).map { |a, n| a.to_s(n) }.join(", ")
      else
        str << args2.join(", ")
      end
    end
    str = "#{name}(#{str})"
    if @return_type
      @return_type.to_s(str)
    else
      str
    end
  end

end

class Meth
  attr_reader :mfunc, :visibility, :inheritance, :vfptr_offset
  def initialize(mfunc, visibility, inheritance, vfptr_offset)
    @mfunc, @visibility, @inheritance, @vfptr_offset = mfunc, visibility, inheritance, vfptr_offset
  end

  def introducing_virtual?
    @inheritance.match(/INTRO/)
  end

  def pure?
    @inheritance.match(/PURE/)
  end

  def virtual?
    @inheritance.match(/VIRTUAL/) || pure?
  end

  def static?
    @inheritance.match(/STATIC/)
  end

  def to_s(name = nil)
    if !@mfunc.is_a?(MFunction)
      $stderr.puts @mfunc.class
      @mfunc.each { |f|
        $stderr.puts f.class
      }
    end
    s = @mfunc.to_s(name)
    s = s << " = 0" if pure?
    s = "virtual " << s if introducing_virtual?
    s = "static " << s if static?
    s = s << " /* #{visibility} */"
    s
  end
end

class NamedMeth
  attr_reader :name, :methods
  def initialize(name, methods)
    @name, @methods = name, methods
  end

  def print
    $stderr.puts "Warning #{name} not an arr #{methods.class}" if !@methods.is_a?(Array)
    @methods.each { |m|
      pr m.to_s(name) << ";"
    }
  end
end

class Composite
  attr_reader :name
  attr_accessor :members, :size
  class << self
    attr_reader :tag
  end

  def initialize(name, members, size)
    @name, @members, @size = name, members, size
  end

  def print
    if !size
      pr "#{tag} #{@name};"
      return
    end
    parents = []
    named_meths = []
    static_members = []
    list = []
    if @members
      parents = @members.select { |m| m.kind_of?(Parent) || m.kind_of?(VirtualParent) }.map { |p|
        "#{p.visibility} #{p.type.name}" + (p.kind_of?(Parent) ? " /* 0x%08x */" % p.offset : "") }
      named_meths = @members.select { |m| m.kind_of?(NamedMeth) }
      static_members = @members.select { |m| m.kind_of?(StaticMember) }
      list = @members.select { |m| m.kind_of?(Member) }
    end
    vbtable = nil
    vftable = nil
    if self.is_a?(TableComposite) && @members
      if has_vftable?
        vftable = @members.find { |m| m.kind_of?(VFTable) }
        parent = @members.find { |m| m.kind_of?(Parent) && m.type.vftable_name }
        entries = []
        named_meths.each { |nm|
          nm.methods.filter(&:vfptr_offset).each { |m|
            i = m.vfptr_offset/Pointer.size
            # virtual __vecDelDtor seem to override application defined destructor
            entries[i] = [nm.name, m] unless entries[i]
          }
        }
        pr "struct #{@name}::__vftable /* size : 0x%08x */" % (vtshape.num * Pointer.size)
        opn
        if parent
          pr "#{parent.type.vftable_name} _base; /* size : 0x%08x */" % (parent.type.vtshape.num * Pointer.size)
          range = parent.type.vtshape.num..-1
        else
          range = 0..-1
        end
        entries[range].each { |n, t| pr "#{Pointer.new(t.mfunc).to_s(n)}; // 0x%08x" % t.vfptr_offset.to_i if t } if entries[range]
        cls
      end
      if has_vbtable?
        vbtable = true
        virtual_parents = @members.select { |m| m.kind_of?(VirtualParent) || m.kind_of?(IndirectVirtualParent) }
        pr "struct #{@name}::__vbtable /* size : 0x%08x */" % (virtual_parents.size * Pointer.size)
        opn
        virtual_parents.sort { |p1, p2| p1.vbpoff <=> p2.vbpoff }.each_with_index { |p, i|
          pr "#{Pointer.new(p.type).to_s("base%02i" % i)}; // 0x%08x" % p.vbpoff
        }
        cls
      end
    end
    pr "#{tag} #{@name}#{!parents.empty? ? " : " << parents.join(", ") : ""} /* size : 0x%08x */" % size
    opn
    named_meths.each { |meth|
      meth.print
    }
    pr "/*****************************************/"
    static_members.each { |m| pr m.to_s << ";" }
    pr "/*****************************************/"
    pr "#{@name}::__vftable *_vftable; // 0x%08x" % 0 if vftable
    pr "#{@name}::__vbtable _vbtable; // 0x%08x" % (vftable ? Pointer.size : 0) if vbtable
    list.each { |m| pr m.to_s << ";" << (m.offset ? " // 0x%08x" % m.offset : "") }
    cls
  end

  def tag
    self.class.tag
  end

  def to_s(n = nil)
    str = "#{name}"
    str << " #{n}" if n
    str
  end
end

class Union < Composite
  @tag = "union"
end

class TableComposite < Composite
  attr_accessor :vtshape
  def initialize(name, members, size, vtshape)
    super(name, members, size)
    @vtshape = vtshape
  end

  def has_vftable?
    if @vtshape
      p = @members.find { |m| m.kind_of?(Parent) }
      return false if p && p.type.vtshape && p.type.vtshape.num == @vtshape.num
      return true
    end
    false
  end

  def vftable_name
    return "#{@name}::__vftable" if has_vftable?
    p = @members.find { |m| m.kind_of?(Parent) } if @members
    return p.type.vftable_name if p
    nil
  end

  def has_vbtable?
    return true if @members.find { |m| m.kind_of?(VirtualParent) || m.kind_of?(IndirectVirtualParent) }
    return false
  end
end

class Structure < TableComposite
  @tag = "struct"
end

class Cls < TableComposite
  @tag = "class"
end

class Pointer
  attr_reader :type
  attr_reader :size
  def initialize(type, size = Pointer.size)
    @type = type
    @size = size
  end

  def to_s(name = nil)
    str = "*"
    str << "#{name}" if name
    str =
      case @type
      when Procedure, Arr
        "(#{str})"
      when MFunction
        if $cmode
          "(#{str})"
        else
          "(#{@type.class_type.name}::#{str})"
        end
      else
        str
      end
    if @type
      @type.to_s(str)
    else
      str
    end
  end

  def self.size
    $pointer_size
  end
end

class Arr
  attr_reader :type, :length
  def initialize(type, length)
    @type, @length = type, length
  end

  def to_s(name = nil)
    str = "#{name}[#{@length/@type.size}]"
    if @type
      type.to_s(str)
    else
      str
    end
  end

  def size
    length
  end
end

class Modifier
  attr_reader :type, :mod
  def initialize(type, mod)
    @type, @mod = type, mod
  end

  def to_s(name = nil)
    "#{@mod} #{@type.to_s(name)}"
  end

  def size
    @type.size
  end
end

class Parent
  attr_reader :type, :visibility, :offset
  def initialize(type, visibility, offset)
    @type, @visibility, @offset = type, visibility, offset
  end
end

class VirtualParent
  attr_reader :type, :visibility, :vbpoff
  def initialize(type, visibility, vbpoff)
    @type, @visibility, @vbpoff = type, visibility + " virtual", vbpoff
  end
end

class IndirectVirtualParent
  attr_reader :type, :visibility, :vbpoff
  def initialize(type, visibility, vbpoff)
    @type, @visibility, @vbpoff = type, visibility, vbpoff
  end
end

class Nested
  attr_reader :name, :type
  def initialize(name, type)
    @name, @type = name, type
  end
end

class VFTableShape
  attr_reader :num
  def initialize(num)
    @num = num
  end
end

class VFTable
  attr_reader :type
  def initialize(type)
    @type = type
  end
end

class BaseType
  attr_reader :name, :size
  def initialize(name, size)
    @name, @size = name, size
  end

  def to_s(n = nil)
    str = "#{name}"
    str << " #{n}" if n
    str
  end

  CHAR = BaseType.new("char", 1)
  UCHAR = BaseType.new("unsigned char", 1)
  RCHAR = BaseType.new("char", 1)
  SHORT = BaseType.new("short", 2)
  USHORT = BaseType.new("ushort", 2)
  WCHAR = BaseType.new("wchar_t", 2)
  INT = BaseType.new("int", 4)
  UINT = BaseType.new("unsigned int", 4)
  LONG = BaseType.new("long", 4)
  ULONG = BaseType.new("unsigned long", 4)
  QUAD = BaseType.new("int64_t", 8)
  UQUAD = BaseType.new("uint64_t", 8)
  VOID = BaseType.new("void", nil)
  CHAR16 = BaseType.new("char16_t", 2)
  CHAR32 = BaseType.new("char32_t", 4)

  NOTYPE = BaseType.new(nil, nil)

  P32CHAR = Pointer.new(CHAR, 4)
  P32UCHAR = Pointer.new(UCHAR, 4)
  P32SHORT = Pointer.new(SHORT, 4)
  P32USHORT = Pointer.new(USHORT, 4)
  P32WCHAR = Pointer.new(WCHAR, 4)
  P32INT = Pointer.new(INT, 4)
  P32UINT = Pointer.new(UINT, 4)
  P32LONG = Pointer.new(LONG, 4)
  P32ULONG = Pointer.new(ULONG, 4)
  P32VOID = Pointer.new(VOID, 4)
  P32RCHAR = Pointer.new(RCHAR, 4)
  P32QUAD = Pointer.new(QUAD, 4)
  P32UQUAD = Pointer.new(UQUAD, 4)
  PCHAR16 = Pointer.new(CHAR16, 4)
  PCHAR32 = Pointer.new(CHAR32, 4)
  P64VOID = Pointer.new(VOID, 8)
  PVOID = Pointer.new(VOID)

  FLOAT = BaseType.new("float", 4)
  DOUBLE = BaseType.new("double", 8)
  PFLOAT = Pointer.new(FLOAT)
  PDOUBLE = Pointer.new(DOUBLE)

  HRESULT = BaseType.new("HRESULT", 4)
  PHRESULT = Pointer.new(HRESULT)

  CONVERT = {
    "T_CHAR" => CHAR,
    "T_UCHAR" => UCHAR,
    "T_RCHAR" => RCHAR,
    "T_BOOL08" => CHAR,
    "T_SHORT" => SHORT,
    "T_USHORT" => USHORT,
    "T_WCHAR" => WCHAR,
    "T_INT4" => INT,
    "T_UINT4" => UINT,
    "T_LONG" => INT,
    "T_ULONG" => UINT,
    "T_INT8" => QUAD,
    "T_UINT8" => UQUAD,
    "T_QUAD" => QUAD,
    "T_UQUAD" => UQUAD,
    "T_VOID" => VOID,
    "T_CHAR32" => CHAR32,
    "T_CHAR16" => CHAR16,

    "T_32PCHAR" => P32CHAR,
    "T_32PUCHAR" => P32UCHAR,
    "T_32PRCHAR" => P32RCHAR,
    "T_32PBOOL08" => P32CHAR,
    "T_32PSHORT" => P32SHORT,
    "T_32PUSHORT" => P32USHORT,
    "T_32PWCHAR" => P32WCHAR,
    "T_32PINT4" => P32INT,
    "T_32PUINT4" => P32UINT,
    "T_32PLONG" => P32LONG,
    "T_32PULONG" => P32ULONG,
    "T_32PQUAD" => P32QUAD,
    "T_32PUQUAD" => P32UQUAD,
    "T_32PVOID" => P32VOID,
    "T_PVOID" => PVOID,
    "T_32PCHAR16" => PCHAR16,
    "T_32PCHAR32" => PCHAR32,
    "T_64PVOID" =>  P64VOID,

    "T_REAL32" => FLOAT,
    "T_REAL64" => DOUBLE,
    "T_32PREAL32" => PFLOAT,
    "T_32PREAL64" => PDOUBLE,

    "T_32PHRESULT" => PHRESULT,
    "T_HRESULT" => HRESULT,

    "T_NOTYPE" => NOTYPE,
  }

  def self.from_str(str)
    res = CONVERT[str]
    raise "undefined type #{str}" unless res
    res
  end
end

imodules = pdb.index("\n*** MODULES\n\n")

j = pdb.index("\n*** ", imodules+1)

modules = pdb[imodules...j].lines[3..-1].map(&:chomp).map { |l| l.split(" \"").map { |e| e.tr("\"", "") } }.map { |id, *args| [id.to_i, args] }.to_h

ipublics = pdb.index("\n*** PUBLICS\n\n")

j = pdb.index("\n*** ", ipublics+1)

publics = pdb[ipublics...j].lines[3..-1].map(&:chomp).reject { |l| l.empty? }.map { |l| l.match(/S_PUB32: \[(\h+:\h+)\], Flags: (\h+), (.*)/).captures }

itypes = pdb.index("\n*** TYPES\n\n")

j = pdb.index("\n*** ", itypes+1)

types_LF = {}
types = {}

pdb[(itypes + "\n*** TYPES\n\n".length)...j].split("\n\n").map { |l| l.lines.map(&:chomp) }.each { |t|
  id, length, leaf, type = t[0].match(/0x(\h+) : Length = (\d+), Leaf = 0x(\h+) (.*)/).captures
  if $wa
    next if id == "0001d87b" # off by one error
    if id == "e2c2"
      types_LF[0x1d87b].args[0] = types_LF[0xE2C1]
    end
  end
  t2 = []
  t.each { |l|
    l.start_with?("\t\t") ? t2[-1] += l : t2.push(l)
  }
  t = t2
  types_LF[id.to_i(16)] = case type
  when "LF_FIELDLIST"
    t[1..-1].map { |l|
      l.match(/list\[\d+\] = (\w+), (.*)/).captures
    }.filter_map { |c, options|
      case c
      when "LF_ENUMERATE"
        name = options.match(/name = '(\w+)'/)[1]
        value = options.match(/value = (?:\(\w+\) )?(-?\d+)/)[1].to_i
        EnumValue.new( name, value)
      when "LF_MEMBER"
        visibility = options.match(/^([^,]+),/)[1]
        name = options.match(/member name = '(<[^>]+>|\w+)'/)[1].yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)] if type
        type = BaseType.from_str(options.match(/type = (\w+)\(\h+\)/)[1]) unless type
        offset = options.match(/offset = (?:\(\w+\) )?(\d+)/)[1]
        Member.new(name, type, offset, visibility)
      when "LF_STATICMEMBER"
        visibility = options.match(/^([^,]+),/)[1]
        name = options.match(/member name = '(<[^>]+>|\w+)'/)[1].yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)] if type
        type = BaseType.from_str(options.match(/type = (\w+)\(\h+\)/)[1]) unless type
        StaticMember.new(name, type, visibility)
      when "LF_NESTTYPE"
        match = options.match(/type = 0x(\h+)(:?, (.*))/)
        if match
          type, name = *match.captures
          type = types_LF[type[1].to_i(16)]
        else
          type, name = *options.match(/type = (\w+)\(\h+\)(:?, (.*))/)
        end
        Nested.new(name, type)
      when "LF_METHOD"
        name = options.match(/name = '(.*)'/)[1]
        methods = types_LF[options.match(/list = 0x(\h+)/)[1].to_i(16)]
        NamedMeth.new(name, methods)
      when "LF_ONEMETHOD"
        name = options.match(/name = '(.*)'/)[1]
        type = options.match(/index = 0x(\h+)/)
        if type
          if $wa && type[1] == "0001D87B" # off by one error
            types_LF["0001D87B".to_i(16)] =
              MFunction.new(BaseType.from_str("T_INT4"),
                            [],
                            types_LF[0xC537],
                            types_LF[0xC538])
          end
          type = types_LF[type[1].to_i(16)]
        end
        type = BaseType.from_str(options.match(/index = (\w+)\(\h+\)/)[1]) unless type
        mfunc = type
        vfptr_offset = options.match(/vfptr offset = (\d+)/)
        vfptr_offset = vfptr_offset[1].to_i if vfptr_offset
        visibility, inheritance = options.match(/^(\w+), ([^,]+),/).captures
        NamedMeth.new(name, [Meth.new(mfunc, visibility, inheritance, vfptr_offset)])
      when "LF_BCLASS"
        visibility = options.match(/^(\w+), type/)[1]
        offset = options.match(/offset = (?:\(\w+\) )?(\d+)/)[1]
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)] if type
        type = BaseType.from_str(options.match(/type = (\w+)\(\h+\)/)[1]) unless type
        Parent.new(type, visibility, offset)
      when "LF_VBCLASS"
        visibility = options.match(/^(\w+), direct base type/)[1]
        vbpoff = options.match(/vbpoff = (?:\(\w+\) )?(\d+)/)[1].to_i
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)] if type
        type = BaseType.from_str(options.match(/type = (\w+)\(\h+\)/)[1]) unless type
        VirtualParent.new(type, visibility, vbpoff)
      when "LF_IVBCLASS"
        visibility = options.match(/^(\w+), indirect base type/)[1]
        vbpoff = options.match(/vbpoff = (?:\(\w+\) )?(\d+)/)[1].to_i
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)] if type
        type = BaseType.from_str(options.match(/type = (\w+)\(\h+\)/)[1]) unless type
        IndirectVirtualParent.new(type, visibility, vbpoff)
      when "LF_VFUNCTAB"
        type = options.match(/type = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)]
        VFTable.new(type)
      when "LF_INDEX"
        type = options.match(/Type Index = 0x(\h+)/)
        type = types_LF[type[1].to_i(16)]
      else
        raise "unsupported field #{c}"
      end
    }.flatten
  when "LF_ENUM"
    name = t[2].match(/enum name = ([^,]+)/)[1] #.yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
    udt = nil
    udt = t[2].match(/UDT\(0x(\h+)\)/)
    udt = udt[1].to_i(16) if udt
    type = nil
    type = BaseType.from_str(t[1].match(/type = (\w+)\(\h+\)/)[1]) unless t[2].match(/FORWARD REF/)
    values = nil
    values = types_LF[t[1].match(/field list type 0x(\h+)/)[1].to_i(16)] unless t[2].match(/FORWARD REF/)
    decl = types[udt]
    if decl
      decl.values = values unless decl.values
      decl.type = type unless decl.type
      decl
    else
      enum = Enum.new(name, type, values)
      types[udt] = enum if udt
      enum
    end
  when "LF_BITFIELD"
    bits = t[1].match(/bits = (\d+)/)[1].to_i
    start = t[1].match(/starting position = (\d+)/)[1].to_i
    type = t[1].match(/Type = 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[1].match(/Type = (\w+)\(\h+\)/)[1]) unless type
    BitfieldValue.new(bits, start, type)
  when "LF_UNION"
    name = t[1].match(/class name = ([^,]+)/)[1] #.yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
    udt = t[1].match(/UDT\(0x(\h+)\)/)
    udt = udt[1].to_i(16) if udt
    members = nil
    members = types_LF[t[1].match(/field list type 0x(\h+)/)[1].to_i(16)] unless t[1].match(/FORWARD REF/)
    size = nil
    size = t[1].match(/Size = (?:\(\w+\) )?(\d+)/)[1].to_i unless t[1].match(/FORWARD REF/)
    decl = types[udt]
    if decl
      decl.members = members unless decl.members
      decl.size = size unless decl.size
      decl
    else
      union = Union.new(name, members, size)
      types[udt] = union if udt
      union
    end
  when "LF_STRUCTURE"
    name = t[3].match(/class name = ([^,]+)/)[1] #.yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
    udt = t[3].match(/UDT\(0x(\h+)\)/)
    udt = udt[1].to_i(16) if udt
    # try using unique name as udt
    if !udt
      udt = t[3].match(/unique name = ([^,]+)/)
      udt = udt[1] if udt
    end
    members = nil
    size = nil
    vtshape = nil
    unless t[1].match(/FORWARD REF/)
      members = types_LF[t[1].match(/field list type 0x(\h+)/)[1].to_i(16)]
      size = t[3].match(/Size = (?:\(\w+\) )?(\d+)/)[1].to_i
      vtshape = types_LF[t[2].match(/VT shape type 0x(\h+)/)[1].to_i(16)]
    end

    decl = types[udt]
    if decl
      decl.members = members if members
      decl.size = size if size
      decl.vtshape = vtshape if vtshape
      decl
    else
      struct = Structure.new(name, members, size, vtshape)
      types[udt] = struct if udt
      struct
    end
  when "LF_CLASS"
    if t[3].match(/unique name =/)
      name = t[3].match(/class name = (.*), unique name/)[1] #.yield_self { |v| v.match(/<[^>]+>/) ? nil : v }
    elsif t[3].match(/, UDT\(0x\h+\)/)
      name = t[3].match(/class name = (.*), UDT/)[1]
    else
      name = t[3].match(/class name = (.*)/)[1]
    end
    udt = t[3].match(/UDT\(0x(\h+)\)/)
    udt = udt[1].to_i(16) if udt
    members = nil
    size = nil
    unless t[1].match(/FORWARD REF/)
      members = types_LF[t[1].match(/field list type 0x(\h+)/)[1].to_i(16)]
      size = t[3].match(/Size = (?:\(\w+\) )?(\d+)/)[1].to_i
      vtshape = types_LF[t[2].match(/VT shape type 0x(\h+)/)[1].to_i(16)]
    end

    decl = types[udt]
    if decl
      decl.members = members if members
      decl.size = size if size
      decl.vtshape = vtshape if vtshape
      decl
    else
      struct = Cls.new(name, members, size, vtshape)
      types[udt] = struct if udt
      struct
    end
  when "LF_POINTER"
    type = t[2].match(/Element type : 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[2].match(/Element type : (\w+)\(\h+\)/)[1]) unless type
    Pointer.new(type)
  when /LF_ARGLIST/
    t[1..-1].map { |l|
      type = l.match(/list\[\d+\] = 0x(\h+)/)
      type = types_LF[type[1].to_i(16)] if type
      type = BaseType.from_str(l.match(/list\[\d+\] = (\w+)\(\h+\)/)[1]) unless type
      type
    }
  when "LF_PROCEDURE"
    type = t[1].match(/Return type = 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[1].match(/Return type = (\w+)\(\h+\)/)[1]) unless type
    args = types_LF[t[3].match(/Arg list type = 0x(\h+)/)[1].to_i(16)]
    Procedure.new(type, args)
  when "LF_ARRAY"
    type = t[1].match(/Element type = 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[1].match(/Element type = (\w+)\(\h+\)/)[1]) unless type
    length = t[3].match(/length = (?:\(\w+\) )?(\d+)/)
    length = length[1].to_i if length
    Arr.new(type, length)
  when "LF_MODIFIER"
    type = t[1].match(/modifies type 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[1].match(/modifies type (\w+)\(\h+\)/)[1]) unless type
    mod = t[1].match(/^\t(.*), modifies type/)[1]
    Modifier.new(type, mod)
  when "LF_MFUNCTION"
    type = t[1].match(/Return type = 0x(\h+)/)
    type = types_LF[type[1].to_i(16)] if type
    type = BaseType.from_str(t[1].match(/Return type = (\w+)\(\h+\)/)[1]) unless type
    class_type = types_LF[t[1].match(/Class type = 0x(\h+)/)[1].to_i(16)]
    this_type = t[1].match(/This type = 0x(\h+)/)
    this_type = types_LF[t[1].match(/This type = 0x(\h+)/)[1].to_i(16)] if this_type
    args = types_LF[t[3].match(/Arg list type = 0x(\h+)/)[1].to_i(16)]
    MFunction.new(type, args, class_type, this_type)
  when "LF_METHODLIST"
    t[1..-1].map { |l|
      visibility, inheritance = l.match(/list\[\d+\] = (\w+), ([^,]+)/).captures
      mfunc = types_LF[l.match(/, 0x(\h+),/)[1].to_i(16)]
      vfptr_offset = l.match(/vfptr offset = (\d+)/)
      vfptr_offset = vfptr_offset[1].to_i if vfptr_offset
      Meth.new(mfunc, visibility, inheritance, vfptr_offset)
    }
  when "LF_VTSHAPE"
    num = t[1].match(/Number of entries : (\d+)/)[1].to_i
    VFTableShape.new(num)
  else
    raise "unsupported #{type}"
  end
}

$frames = pdb.scan(/\(\h+\) S_(?:G|L)PROC32: .*?S_END/m).map(&:lines).select { |b|
  !b[0].match(/Type:\s+T_NOTYPE/)
}.map { |b|
  [b[0].match(/Type:\s+0x(\h+), (.*)$/).captures, b.select { |l| l.match(/S_REGISTER|S_REGREL32/) }]
}.map { |(type, name), args|
  args.map! { |l|
    match = l.match(/Type:\s+0x(\h+), (.*)/)
    if match
      t, n = *match.captures
      t = types_LF[t.to_i(16)]
    else
      t, n = *l.match(/Type:\s+(\w+)\(\h+\), (.*)/).captures
      t = BaseType.from_str(t)
    end
    [t, n, l.match(/S_REGISTER|S_REGREL32/)[0]]
  }
  [[name, types_LF[type.to_i(16)]], args]
}.to_h
$frame_names = Set.new( $frames.keys.map { |n, _| n } )

types_LF.values.select { |t| t.kind_of?(Composite) || t.kind_of?(Enum) }.uniq.each { |t|
  pr "/*--------------------------------------------------*/"
  t.print
}

pr "/****************************************************/"

$frames.each { |(n, t), _|
  pr t.to_s(n) if t.kind_of?(Procedure)
}

pr "/****************************************************/"

symbols = pdb.scan(/^S_(?:G|L)DATA32: .*$/).map { |l|
  match = l.match(/32: \[(\h+:\h+)\]/)
  location = match[1].split(":").map { |s| s.to_i(16) }
  match = l.match(/Type:\s+0x(\h+), (.*)/)
  if match
    t, n = *match.captures
    t = types_LF[t.to_i(16)]
  else
    t, n = *l.match(/Type:\s+(\w+)\(\d+\), (.*)/).captures
    t = BaseType.from_str(t)
  end
  [t, n, location]
}

symbols.sort { |s1, s2| s1[2] <=> s2[2] }.each { |t, n, (s, a)|
  pr t.to_s(n) + "; // [%04x:%08x]" % [s, a]
}
#pr "/****************************************************/"
#
#pdb.scan(/^S_LDATA32: .*$/).map { |l|
#  match = l.match(/Type:\s+0x(\h+), (.*)/)
#  if match
#    t, n = *match.captures
#    t = types_LF[t.to_i(16)]
#  else
#    t, n = *l.match(/Type:\s+(\w+)\(\d+\), (.*)/).captures
#    t = BaseType.from_str(t)
#  end
#  pr t.to_s(n) + ";"
#}
