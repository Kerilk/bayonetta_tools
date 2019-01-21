#!ruby
require 'assimp'
require 'optparse'
require 'set'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta

source = ARGV[0]
format = ARGV[1]

raise "Invalid file #{source}" unless File::file?(source)

Dir.mkdir("assimp_output") unless Dir.exist?("assimp_output")

log = Assimp::LogStream::stderr
log.attach
Assimp::LogStream::verbose(1)

module Assimp
  class SceneCreated < Scene
    def self.release
    end
  end
end

extension = nil
Assimp::export_format_descriptions.each { |d|
  if d.id.to_s == format
    extension = d.file_extension
  end
}
raise "Unsupported format: #{format}!" unless extension

#Let's keep references here to avoid garbage collection.
$objects = Hash::new { |h,k| h[k] = [] }
ptr = FFI::MemoryPointer::new(Assimp::SceneCreated)
$objects[:pointers].push ptr
p = FFI::Pointer::new(ptr)
$scene = Assimp::SceneCreated::new(p)
$root_node = Assimp::Node::new
$root_node.name.data = File::basename(source, ".wmb")
$root_node.transformation.identity!
$scene[:root_node] = $root_node

$meshes = []
$materials = []
$mesh_nodes = []
$num_meshes = 0

$wmb = WMBFile::load(source)
#Meshes

def create_vertex_properties(mesh, vertices)
  vertex_map = vertices.each_with_index.collect.to_h
  num_vertices = vertices.size
  mesh.num_vertices = num_vertices
  fields = $wmb.get_vertex_fields
  res = {}
  num_colors = 0
  num_texture_coords = 0
  fields.each { |field|
    case field
    when :position
      ptr = FFI::MemoryPointer::new(Assimp::Vector3D, num_vertices)
      $objects[:pointers].push ptr
      mesh[:vertices] = ptr
      positions = mesh.vertices
      vertex_map.each { |orig_index, index|
        o_p = $wmb.get_vertex_field(field, orig_index)
        p = positions[index]
        p.x = o_p.x
        p.y = o_p.y
        p.z = o_p.z
      }
      res[:vertices] = ptr
    when :normal
      ptr = FFI::MemoryPointer::new(Assimp::Vector3D, num_vertices)
      $objects[:pointers].push ptr
      mesh[:normals] = ptr
      normals = mesh.normals
      vertex_map.each { |orig_index, index|
        o_n = $wmb.get_vertex_field(field, orig_index)
        n = normals[index]
        n.x = o_n.x
        n.y = o_n.y
        n.z = o_n.z
      }
      res[:normals] = ptr
    when :tangents
      ptr_t = FFI::MemoryPointer::new(Assimp::Vector3D, num_vertices)
      $objects[:pointers].push ptr_t
      mesh[:tangents] = ptr_t
      tangents = mesh.tangents
      normals = mesh.normals
      vertex_map.each { |orig_index, index|
        o_t = $wmb.get_vertex_field(field, orig_index)
        t = tangents[index]
        t.x = o_t.x
        t.y = o_t.y
        t.z = o_t.z
      }
      res[:tangents] = ptr_t
    when :mapping, :mapping2, :mapping3, :mapping4, :mapping5
      ptr = FFI::MemoryPointer::new(Assimp::Vector3D, num_vertices)
      $objects[:pointers].push ptr
      mesh[:texture_coords][num_texture_coords] = ptr
      mesh[:num_uv_components][num_texture_coords] = 2
      sz = Assimp::Vector3D.size
      texture_coords = num_vertices.times.collect { |i|
        Assimp::Vector3D::new(ptr + i*sz)
      }
      vertex_map.each { |orig_index, index|
        m_o = $wmb.get_vertex_field(field, orig_index)
        m = texture_coords[index]
        m.x = m_o.u
        m.y = m_o.v
      }
      res[:"texture_coords#{num_texture_coords}"] = ptr
      num_texture_coords += 1
    when :color, :color2
      ptr = FFI::MemoryPointer::new(Assimp::Color4D, num_vertices)
      $objects[:pointers].push ptr
      mesh[:colors][num_colors] = ptr
      sz = Assimp::Color4D.size
      colors = num_vertices.times.collect { |i|
        Assimp::Color4D::new(ptr + i*sz)
      }
      vertex_map.each { |orig_index, index|
        c_o = $wmb.get_vertex_field(field, orig_index)
        c = colors[index]
        c.r = c_o.r.to_f / 255.0
        c.g = c_o.g.to_f / 255.0
        c.b = c_o.b.to_f / 255.0
        c.a = c_o.a.to_f / 255.0
      }
      res[:"colors#{num_colors}"] = ptr
      num_colors += 1
    else
      puts "skipping #{field}" unless :bone_infos
    end
  }
  if res[:normals] && res[:tangents]
    ptr_bt = FFI::MemoryPointer::new(Assimp::Vector3D, num_vertices)
    $objects[:pointers].push ptr_bt
    mesh[:bitangents] = ptr_bt
    tangents = mesh.tangents
    bitangents = mesh.bitangents
    normals = mesh.normals
    vertex_map.each { |orig_index, index|
      o_t = $wmb.get_vertex_field(:tangents, orig_index)
      t = tangents[index]
      n = normals[index]
      n_b_t = (n ^ t)
      n_b_t = ( o_t.s > 0 ? n_b_t * -1.0 : n_b_t )
      b_t = bitangents[index]
      b_t.x = n_b_t.x
      b_t.y = n_b_t.y
      b_t.z = n_b_t.z
    }
    res[:bitangents] = ptr_bt
  end
  res
end

def create_mesh( m, i, b, j)
    uniq_vertices = b.vertex_indices.uniq.sort
    vertex_map = uniq_vertices.each_with_index.collect.to_h
    num_vertices = uniq_vertices.size
    first_index = uniq_vertices.first
    triangles = b.triangles
    num_triangles = triangles.size    

    mesh = Assimp::Mesh::new
    mesh.primitive_types = :TRIANGLE
    mesh.name = "_#{"%02d" % i}_#{m.header.name}_#{"%02d" % j}_"
    res = create_vertex_properties(mesh, uniq_vertices)
    if $wmb.tex_infos then
      mesh.material_index = b.header.ex_mat_id
    else
      mesh.material_index = b.header.material_id
    end

    mesh.num_faces = num_triangles
    ptr = FFI::MemoryPointer::new(Assimp::Face, num_triangles)
    $objects[:pointers].push ptr
    mesh[:faces] = ptr
    faces = mesh.faces
    faces.each_with_index { |f, i|
      f.num_indices = 3
      ptr = FFI::MemoryPointer::new(:uint, 3)
      $objects[:pointers].push ptr
      t = triangles[i].collect{ |v| vertex_map[v] }
      #Bayonetta Triangles are winded backward
      t[1], t[2] = t[2], t[1]
      ptr.write_array_of_uint(t)
      f[:indices] = ptr
    }

    $meshes.push mesh
    mesh
end

$wmb.materials.each_with_index { |m, i|
  mat = Assimp::Material::new
  properties = []
  ptr = FFI::MemoryPointer::new(Assimp::MaterialProperty)
  $objects[:pointers].push ptr
  properties.push ptr

  ptr = FFI::MemoryPointer::new(:pointer, properties.length)
  $objects[:pointers].push ptr
  ptr.write_array_of_pointer(properties)
  mat[:properties] = ptr
  mat.num_properties = 1
  mat.num_allocated = 1
  props = mat.properties
  name_prop = props.first
  name_prop.key.data = Assimp::MATKEY_NAME
  name_prop.type = :String

  name = "mat_#{"%02d" % i}"
  ptr = FFI::MemoryPointer::from_string(name)
  str = FFI::MemoryPointer::new(ptr.size+4)
  str.write_uint(ptr.size - 1)
  str.put_array_of_char(4, ptr.read_array_of_char(ptr.size))
  $objects[:strings].push str
  
  name_prop.data_length = str.size
  name_prop[:data] = str
  $materials.push mat
}
 
$wmb.meshes.each_with_index { |m, i|
  batches = []
  $objects[:meshes].push batches
  m.batches.each_with_index { |b, j|
    batches.push create_mesh(m, i, b, j)
  }
  n = Assimp::Node::new
  n.transformation.identity!
  n.name.data = m.header.name
  n.num_meshes = batches.length
  ptr = FFI::MemoryPointer::new(:uint, batches.length)
  $objects[:pointers].push ptr
  ptr.write_array_of_uint(($num_meshes...($num_meshes+batches.length)).to_a)
  n[:meshes] = ptr
  n[:parent] = $root_node.pointer
  $num_meshes += batches.length
  $mesh_nodes.push n
}

$root_node.num_children = $mesh_nodes.length
ptr = FFI::MemoryPointer::new(:pointer, $mesh_nodes.length)
$objects[:pointers].push ptr
ptr.write_array_of_pointer($mesh_nodes.collect(&:pointer))
$root_node[:children] = ptr

$scene.num_meshes = $meshes.length
ptr = FFI::MemoryPointer::new(:pointer, $meshes.length)
$objects[:pointers].push ptr
ptr.write_array_of_pointer($meshes.collect(&:pointer))
$scene[:meshes] = ptr

$scene.num_materials = $materials.length
ptr = FFI::MemoryPointer::new(:pointer, $materials.length)
$objects[:pointers].push ptr
ptr.write_array_of_pointer($materials.collect(&:pointer))
$scene[:materials] = ptr


output_dir = "assimp_output/#{$root_node.name.to_s}_#{format}"
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
$scene.export(format, output_dir+"/#{$root_node.name.to_s}.#{extension}")
