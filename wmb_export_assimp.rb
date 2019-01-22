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

#log = Assimp::LogStream::stderr
#log.attach
#Assimp::LogStream::verbose(1)

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
$scene.flags = [:NON_VERBOSE_FORMAT, :FLAGS_ALLOW_SHARED]
$root_node = Assimp::Node::new
$root_node.name = File::basename(source, ".wmb")
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
      mesh.vertices = vertex_map.collect { |orig_index, index|
        p = Assimp::Vector3D::new
        o_p = $wmb.get_vertex_field(field, orig_index)
        p.x = o_p.x
        p.y = o_p.y
        p.z = o_p.z
        p
      }
    when :normal
      mesh.normals = vertex_map.collect { |orig_index, index|
        n = Assimp::Vector3D::new
        o_n = $wmb.get_vertex_field(field, orig_index)
        n.x = o_n.x
        n.y = o_n.y
        n.z = o_n.z
        n
      }
    when :tangents
      mesh.tangents = vertex_map.collect { |orig_index, index|
        t = Assimp::Vector3D::new
        o_t = $wmb.get_vertex_field(field, orig_index)
        t.x = o_t.x
        t.y = o_t.y
        t.z = o_t.z
        t
      }
    when :mapping, :mapping2, :mapping3, :mapping4, :mapping5
      coords = vertex_map.collect { |orig_index, index|
        m = Assimp::Vector3D::new
        m_o = $wmb.get_vertex_field(field, orig_index)
        m.x = m_o.u
        m.y = m_o.v
        m
      }
      mesh.num_uv_components[num_texture_coords] = 2
      mesh.set_texture_coords(num_texture_coords, coords)
      num_texture_coords += 1
    when :color, :color2
      colors = vertex_map.collect { |orig_index, index|
        c = Assimp::Color4D::new
        c_o = $wmb.get_vertex_field(field, orig_index)
        c.r = c_o.r.to_f / 255.0
        c.g = c_o.g.to_f / 255.0
        c.b = c_o.b.to_f / 255.0
        c.a = c_o.a.to_f / 255.0
        c
      }
      mesh.set_colors(num_colors, colors)
      num_colors += 1
    else
      puts "skipping #{field}" unless :bone_infos
    end
  }
  if mesh.normals? && mesh.tangents?
    tangents = mesh.tangents
    normals = mesh.normals
    mesh.bitangents = vertex_map.collect { |orig_index, index|
      b_t = Assimp::Vector3D::new
      o_t = $wmb.get_vertex_field(:tangents, orig_index)
      t = tangents[index]
      n = normals[index]
      n_b_t = (n ^ t)
      n_b_t = ( o_t.s > 0 ? n_b_t * -1.0 : n_b_t )
      b_t.x = n_b_t.x
      b_t.y = n_b_t.y
      b_t.z = n_b_t.z
      b_t
    }
  end
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
  name_prop.key = Assimp::MATKEY_NAME
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
 
def create_mesh( m, i, b, j)
    uniq_vertices = b.vertex_indices.uniq.sort
    vertex_map = uniq_vertices.each_with_index.collect.to_h
    num_vertices = uniq_vertices.size
    first_index = uniq_vertices.first
    triangles = b.triangles
    num_triangles = triangles.size    

    mesh = Assimp::Mesh::new
    mesh.primitive_types = :TRIANGLE
    mesh.name = ("%02d_" % i) + m.header.name.delete("\000")+("_%02d" % j)
    res = create_vertex_properties(mesh, uniq_vertices)
    if $wmb.tex_infos then
      mesh.material_index = b.header.ex_mat_id
    else
      mesh.material_index = b.header.material_id
    end

    mesh.faces = triangles.collect { |tri|
      f = Assimp::Face::new
      t = tri.collect{ |v| vertex_map[v] }
      t[1], t[2] = t[2], t[1]
      f.indices = t
      $objects[:faces].push f
      f
    }

    $meshes.push mesh

    n = Assimp::Node::new
    n.transformation.identity!
    n.name = mesh.name
    n.meshes = [$num_meshes]
    $num_meshes += 1
    n
end

$wmb.meshes.each_with_index { |m, i|
  batches = []
  $objects[:meshes].push batches
  n = Assimp::Node::new
  m.batches.each_with_index { |b, j|
    b = create_mesh(m, i, b, j)
    b[:parent] = n.pointer
    batches.push b
#    $mesh_nodes.push b
  }
  n.transformation.identity!
  n.name = ("%02d_"%i) + m.header.name
  n.num_children = batches.length
  ptr = FFI::MemoryPointer::new(:pointer, batches.length)
  $objects[:pointers].push ptr
  ptr.write_array_of_pointer(batches.collect(&:pointer))
  n[:children] = ptr
  n[:parent] = $root_node.pointer
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
