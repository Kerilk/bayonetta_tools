require 'nokogiri'
require 'set'

module Bayonetta
#=begin
  class BXMFile < LibBin::DataConverter

    class Datum < LibBin::DataConverter
      uint16 :name_offset
      int16 :value_offset
    end

    class Node < LibBin::DataConverter
      uint16 :child_count
      uint16 :first_child_index
      uint16 :attribute_count
      uint16 :datum_index
    end

    class Header < LibBin::DataConverter
      string :id, 4
      uint32 :unknown
      uint16 :node_count
      uint16 :datum_count
      uint32 :data_size
    end

    register_field :header, Header
    register_field :nodes, Node, count: 'header\node_count'
    register_field :datums, Datum, count: 'header\datum_count'
    string :data, 'header\data_size'

    def get_data_strings
      io = StringIO::new(data, "rb")
      pos = 0
      data_strings = {-1 => nil}
      while (l = io.gets("\0"))
        data_strings[pos] = l.unpack("Z*").first
        pos = io.tell
      end
      data_strings
    end

    def get_datas
      data_strings = get_data_strings
      datums.collect { |d| [data_strings[d.name_offset], data_strings[d.value_offset]] }
    end

    def build_xml_tree(doc, index, datas)
      node = nodes[index]
      name, value = datas[node.datum_index]
      n = Nokogiri::XML::Node.new(name, doc)
      n.content = value if value
      node.attribute_count.times { |i|
        name, value = datas[node.datum_index + i + 1]
        n[name] = value
      }
      node.child_count.times { |i|
        n << build_xml_tree(doc, node.first_child_index + i, datas)
      }
      n
    end

    def to_xml
      datas = get_datas
      doc = Nokogiri::XML::Document::new
      doc << build_xml_tree(doc, 0, datas) if header.node_count > 0
      doc
    end

    def process_node(node, index, next_node_index)
      name = node.name
      children = node.elements
      value = node.content if children.empty?
      value = value.strip if value
      value = nil if value == ''
      attributes = node.attributes

      n = Node.new
      n.child_count = children.size
      n.first_child_index = next_node_index
      n.attribute_count = attributes.size
      nodes[index] = n

      node_datums = [[name, value]]
      attributes.each { |k, v| node_datums.push [k, v.value] }
      datum_index = datums.each_cons(node_datums.size).find_index { |sub| sub == node_datums }
      if datum_index
        n.datum_index = datum_index
      else
        n.datum_index = datums.size
        datums.push *node_datums
        node_datums.flatten.each { |v| data.add v if v }
      end
      next_node_index += children.size
      children.each_with_index { |c, i|
        next_node_index = process_node(c, n.first_child_index + i, next_node_index)
      }
      next_node_index
    end

    def from_xml(xml, tag)
      @header = Header.new
      @nodes = []
      @datums = []
      @data = Set.new
      header.id = tag
      header.unknown = 0
      process_node(xml.children.first, 0, 1)
      header.node_count = nodes.length
      header.datum_count = datums.length
      io = StringIO::new("", "wb")
      data_map = data.collect { |d|
        pos = io.tell
        io.write(d, "\0")
        [d, pos]
      }.to_h
      data_map[nil] = -1
      datums.collect! { |n, v|
        d = Datum.new
        d.name_offset = data_map[n]
        d.value_offset = data_map[v]
        d
      }
      @data = io.string
      header.data_size = data.bytesize
      self
    end

    def self.from_xml(xml, tag="BXM\0")
      bxm = self.new
      bxm.from_xml(xml, tag)
    end

    def self.is_big?(f)
      true
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        File.open(input_name, "rb") { |f|
          input = StringIO::new(f.read, "rb")
        }
      end
      tag = input.read(4).unpack("a4").first
      raise "invalid file type #{tag}!" if tag != "XML\0" && tag != "BXM\0"
      input.rewind
      bxm = self.new
      big = input_big = is_big?(input)
      bxm.instance_variable_set(:@__was_big, big)
      bxm.__load(input, big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      bxm
    end

    def dump(output_name, output_big = true)
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = StringIO::new("", "wb")
      end

      __set_dump_state(output, output_big, nil, nil)
      __dump_fields
      __unset_dump_state

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
