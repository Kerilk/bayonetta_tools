require 'nokogiri'

input_file = ARGV[0]

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

def read_nodes(f, base_offset, node_number)
  f.seek(base_offset)
  f.read(node_number*8).unpack("S>*").each_slice(4).collect{ |param|
    Node::new(*param)
  }
end

def read_data_offsets(f, base_offset, data_number)
  f.seek(base_offset)
  f.read(data_number*4).unpack("s>*").each_slice(2).to_a
end

def read_data_blob(f, base_offset, data_offsets, data_number)
  data_offsets.collect { |name_offset, value_offset|
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

def build_xml_tree(doc, nodes, data, index = 0)
  d = data[nodes[index].data_index]
  n = Nokogiri::XML::Node.new d.name, doc
  if d.value
    n.content = d.value
  end
  nodes[index].attribute_number.times { |i|
    d = data[nodes[index].data_index + 1 + i]
    n[d.name] = d.value
  }
  nodes[index].child_number.times { |i|
    n << build_xml_tree(doc, nodes, data, nodes[index].first_child_index + i)
  }
  n
end

File::open(input_file, "rb") { |f|
  id = f.read(4)
  raise "Invalid file type #{id}!" unless id == "XML\x00"
  u = f.read(4).unpack("L>").first
  node_number = f.read(2).unpack("S>").first
  data_number = f.read(2).unpack("S>").first
  data_size = f.read(4).unpack("L>").first

  nodes = read_nodes(f, 0x10, node_number)

  data_offsets = read_data_offsets(f, 0x10 + node_number * 8, data_number)

  data = read_data_blob(f, 0x10 + node_number * 8 + data_number * 4, data_offsets, data_number)

  nodes
  data_offsets
  data
  doc = Nokogiri::XML::Document::new
  doc << build_xml_tree(doc, nodes, data)
  print doc.to_xml
}
