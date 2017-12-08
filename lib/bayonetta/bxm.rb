require 'nokogiri'

module Bayonetta

  class BXMFile
    class Node
      attr_reader :child_number
      attr_reader :first_child_index
      attr_reader :attribute_number
      attr_reader :data_index
      def initialize(child_number, first_child_index, attribute_number, data_index)
        @child_number = child_number
        @first_child_index = first_child_index
        @attribute_number = attribute_number
        @data_index = data_index
      end
    end

    class DataItem
      attr_reader :name, :value
      def initialize(name, value = nil)
        @name = name
        @value = value
      end
    end

    private

    def read_nodes(f, base_offset)
      f.seek(base_offset)
      f.read(@node_number*8).unpack("S>*").each_slice(4).collect{ |param|
        Node::new(*param)
      }
    end

    def read_data_offsets(f, base_offset)
      f.seek(base_offset)
      f.read(@data_number*4).unpack("s>*").each_slice(2).to_a
    end

    def read_data_blob(f, base_offset)
      @data_offsets.collect { |name_offset, value_offset|
        f.seek(base_offset + name_offset)
        name = f.readline("\x00").chomp("\x00")
        if value_offset != -1
          f.seek(base_offset + value_offset)
          value = f.readline("\x00").chomp("\x00")
        else
          value = nil
        end
        DataItem::new(name, value)
      }
    end

    def build_xml_tree(doc, index = 0)
      d = @data[@nodes[index].data_index]
      n = Nokogiri::XML::Node.new d.name, doc
      if d.value
        n.content = d.value
      end
      @nodes[index].attribute_number.times { |i|
        d = @data[@nodes[index].data_index + 1 + i]
        n[d.name] = d.value
      }
      @nodes[index].child_number.times { |i|
        n << build_xml_tree(doc, @nodes[index].first_child_index + i)
      }
      n
    end

    public

    attr_reader :id
    attr_reader :u
    attr_reader :node_number
    attr_reader :data_number
    attr_reader :data_size

    attr_reader :nodes
    attr_reader :data_offsets
    attr_reader :data

    def initialize(f, big=true)
      @id = f.read(4)
      raise "Invalid file type #{id}!" unless @id == "XML\x00" || @id == "BXM\x00"
      @u = f.read(4).unpack("L>").first
      @node_number = f.read(2).unpack("S>").first
      @data_number = f.read(2).unpack("S>").first
      @data_size = f.read(4).unpack("L>").first

      @nodes = read_nodes(f, 0x10)

      @data_offsets = read_data_offsets(f, 0x10 + @node_number * 8)

      @data = read_data_blob(f, 0x10 + @node_number * 8 + @data_number * 4)

    end

    def to_xml
      doc = Nokogiri::XML::Document::new
      doc << build_xml_tree(doc)
      doc
    end

    def self.load(input_name, big = true)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      c = self::new(input)
      c
    end

  end

end
