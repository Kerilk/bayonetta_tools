#!ruby
require 'assimp-ffi'
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

    def initialize
      @ref_ptr = FFI::MemoryPointer::new(Assimp::SceneCreated)
      super(FFI::Pointer::new(@ref_ptr))
    end

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

$scene = Assimp::SceneCreated::new
$scene.flags = [:NON_VERBOSE_FORMAT, :FLAGS_ALLOW_SHARED]
$root_node = Assimp::Node::new
$root_node.name = File::basename(source, ".wmb")
$scene[:root_node] = $root_node

$meshes = []
$num_meshes = 0

$wmb = WMBFile::load(source)
tex_file_name = source.gsub(/wmb\z/,"wtb")
$wtb = WTBFile::new(File::new(tex_file_name, "rb"))
#Meshes

def create_bone_hierarchy
  skeleton = Assimp::Node::new
  skeleton.name = "skeleton"

  bones = $wmb.get_bone_structure
  table = $wmb.bone_index_translate_table.table.invert
  $bone_nodes = bones.collect { |b|
    n = Assimp::Node::new
    n.name = "bone_%03d" % b.index
    n.transformation = Assimp::Matrix4x4.translation(b.relative_position)
    n
  }
  sekeleton_children = []
  bones.zip($bone_nodes).each_with_index { |(b, n), i|
    if b.parent
      n.parent = $bone_nodes[b.parent.index]
    else
      n.parent = skeleton
      sekeleton_children.push(n)
    end
    n.children = b.children.collect { |c| $bone_nodes[c.index] }
  }
  skeleton.children = sekeleton_children
  skeleton
end

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
#      colors = vertex_map.collect { |orig_index, index|
#        c = Assimp::Color4D::new
#        c_o = $wmb.get_vertex_field(field, orig_index)
#        c.r = c_o.r.to_f / 255.0
#        c.g = c_o.g.to_f / 255.0
#        c.b = c_o.b.to_f / 255.0
#        c.a = c_o.a.to_f / 255.0
#        c
#      }
#      mesh.set_colors(num_colors, colors)
#      num_colors += 1
    else
      puts "skipping #{field}" unless field == :bone_infos
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


 
def create_mesh( m, i, b, j)
    uniq_vertices = b.vertex_indices.uniq.sort
    vertex_map = uniq_vertices.each_with_index.collect.to_h
    num_vertices = uniq_vertices.size
    first_index = uniq_vertices.first
    triangles = b.triangles
    num_triangles = triangles.size    

    mesh = Assimp::Mesh::new
    mesh.primitive_types = :TRIANGLE
    mesh.name = ("batch_%02d_" % i) + m.header.name.delete("\000")+("_%02d" % j)
    res = create_vertex_properties(mesh, uniq_vertices)
    if $wmb.tex_infos then
      mesh.material_index = b.header.ex_mat_id
    else
      mesh.material_index = b.header.material_id
    end

    mesh.faces = triangles.collect { |tri|
      f = Assimp::Face::new
      t = tri.collect{ |v| vertex_map[v] }
      f.indices = t
      f
    }

    $meshes.push mesh

    n = Assimp::Node::new
    n.name = mesh.name
    n.meshes = [$num_meshes]
    $num_meshes += 1
    n
end

$root_node.children =[create_bone_hierarchy] + $wmb.meshes.each_with_index.collect { |m, i|
  n = Assimp::Node::new
  n.name = ("mesh_%02d_"%i) + m.header.name
  n.children = m.batches.each_with_index.collect { |b, j|
    b = create_mesh(m, i, b, j)
    b.parent = n
    b
  }
  n.parent = $root_node
  n
}

$scene.meshes = $meshes

$texture_names = $wtb.each.each_with_index.collect { |info_f, i|
  info, f = info_f
  ext, _, _ = info
  "./#{$root_node.name}_#{"%02d"%i}#{ext}"
}
$texture_count = $texture_names.count
fields = $wmb.get_vertex_fields
$scene.materials = $wmb.advanced_materials.each_with_index.collect { |m, i|
  mat = Assimp::Material::new

  mat.add_property(Assimp::MATKEY_NAME, "mat_%02d" % i)
  mat.add_property(Assimp::MATKEY_SHADING_MODEL, :Phong)
  mat.add_property(Assimp::MATKEY_TWOSIDED, false)
  mat.add_property(Assimp::MATKEY_ENABLE_WIREFRAME, false)
#  c = Assimp::Color4D::new.set(0.0, 0.0, 0.0, 1.0)
#  mat.add_property(Assimp::MATKEY_COLOR_EMISSIVE, c)
#  c = Assimp::Color4D::new.set(0.0, 0.0, 0.0, 0.0)
#  mat.add_property(Assimp::MATKEY_COLOR_REFLECTIVE, c)
#  mat.add_property(Assimp::MATKEY_REFLECTIVITY, 0.0)
#  mat.add_property(Assimp::MATKEY_REFRACTI, 1.55)
#  mat.add_property(Assimp::MATKEY_OPACITY, 1.0)

  if m.kind_of?(WMBFile::Bayo1Material)
    if m.parameters["diffuse"]
      c = Assimp::Color4D::new.set(m.parameters["diffuse"][0],
                                   m.parameters["diffuse"][1],
                                   m.parameters["diffuse"][2], 1.0)
      mat.add_property(Assimp::MATKEY_COLOR_DIFFUSE, c)
    end
    if m.parameters["ambient"]
      c = Assimp::Color4D::new.set(m.parameters["ambient"][0],
                                   m.parameters["ambient"][1],
                                   m.parameters["ambient"][2], 1.0)
      mat.add_property(Assimp::MATKEY_COLOR_AMBIENT, c)
    end
    if m.parameters["specular"]
      c = Assimp::Color4D::new.set(m.parameters["specular"][0],
                                   m.parameters["specular"][1],
                                   m.parameters["specular"][2], 1.0)
      mat.add_property(Assimp::MATKEY_COLOR_SPECULAR, c)
    end
    mat.add_property(Assimp::MATKEY_SHININESS, m.parameters["shine"]) if m.parameters["shine"]
    sampler_count = 0
    m.samplers.each { |name, value|
      case name
      when "Color_1", "Color_2", "Color_3"
        next if value >= $texture_count
        index = 0 if name == "Color_1"
        index = 1 if name == "Color_2"
        index = 2 if name == "Color_3"
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :DIFFUSE, index: index)
#        mat.add_property(Assimp::MATKEY_TEXOP, :Multiply, semantic: :DIFFUSE, index: index)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :DIFFUSE, index: index)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :DIFFUSE, index: index)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :DIFFUSE, index: index)
        mat.add_property(Assimp::MATKEY_TEXBLEND, 1.0, semantic: :DIFFUSE, index: index)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :DIFFUSE, index: index)
        tr = Assimp::UVTransform::new
        tr.translation.x = 0
        tr.translation.y = 0
        if name == "Color_1" && m.parameters["Color_1_Tile"]
          tr.scaling.x = m.parameters["Color_1_Tile"][0]
          tr.scaling.y = m.parameters["Color_1_Tile"][1]
        elsif name == "Color_2" && m.parameters["Color_2_Tile"]
          tr.scaling.x = m.parameters["Color_2_Tile"][0]
          tr.scaling.y = m.parameters["Color_2_Tile"][1]
        elsif name == "Color_3" && m.parameters["Color_3_Tile"]
          tr.scaling.x = m.parameters["Color_3_Tile"][0]
          tr.scaling.y = m.parameters["Color_3_Tile"][1]
        else
          tr.scaling.x = 1.0
          tr.scaling.y = 1.0
        end
        tr.rotation = 0.0
        mat.add_property(Assimp::MATKEY_UVTRANSFORM, tr, semantic: :DIFFUSE, index: index)
        sampler_count += 1
      when "effectmap"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :EMISSIVE, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :EMISSIVE, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :EMISSIVE, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :EMISSIVE, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :EMISSIVE, index: sampler_count - 1)
      when "env_amb"
        next if value >= $texture_count || m.samplers.include?("envmap")
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :REFLECTION, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :BOX, semantic: :REFLECTION, index: sampler_count - 1)
      when "envmap"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :REFLECTION, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :BOX, semantic: :REFLECTION, index: sampler_count - 1)
      when "lightmap"
        next if value >= $texture_count
        next unless fields.include?(:mapping2)
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :LIGHTMAP, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :LIGHTMAP, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :LIGHTMAP, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :LIGHTMAP, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_UVWSRC, 1, semantic: :LIGHTMAP, index: sampler_count - 1)
      when "refractmap"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :OPACITY, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :OPACITY, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :OPACITY, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :OPACITY, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :OPACITY, index: sampler_count - 1)
      when "reliefmap"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :NORMALS, index: sampler_count - 1)
    #    mat.add_property(Assimp::MATKEY_TEXOP, :Multiply, semantic: :NORMALS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :NORMALS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :NORMALS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :NORMALS, index: sampler_count - 1)
    #    mat.add_property(Assimp::MATKEY_TEXBLEND, 1.0, semantic: :NORMALS, index: sampler_count - 1)
        uvsrc = 0
        uvsrc = 1 if fields.include?(:mapping2) && !m.parameters.include?("lightmap")
        mat.add_property(Assimp::MATKEY_UVWSRC, uvsrc, semantic: :NORMALS, index: sampler_count - 1)
        tr = Assimp::UVTransform::new
        tr.translation.x = 0
        tr.translation.y = 0
        tr.scaling.x = 1.0
        tr.scaling.y = 1.0
        tr.rotation = 0.0
        mat.add_property(Assimp::MATKEY_UVTRANSFORM, tr, semantic: :NORMALS, index: sampler_count - 1)
      when "Spec_Mask"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :SPECULAR, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :SPECULAR, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :SPECULAR, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :SPECULAR, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :SPECULAR, index: sampler_count - 1)
      when "Spec_Pow"
        next if value >= $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[value], semantic: :SHININESS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPING, :UV, semantic: :SHININESS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :SHININESS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :SHININESS, index: sampler_count - 1)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :SHININESS, index: sampler_count - 1)
      end
    }
  else
    4.times { |j|
      if m.material_data[j] < $texture_count
        mat.add_property(Assimp::MATKEY_TEXTURE, $texture_names[m.material_data[j]], semantic: :DIFFUSE)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_U, :Wrap, semantic: :DIFFUSE)
        mat.add_property(Assimp::MATKEY_MAPPINGMODE_V, :Wrap, semantic: :DIFFUSE)
        mat.add_property(Assimp::MATKEY_TEXBLEND, 1.0, semantic: :DIFFUSE)
        mat.add_property(Assimp::MATKEY_UVWSRC, 0, semantic: :DIFFUSE)
        tr = Assimp::UVTransform::new
        tr.translation.x = 0
        tr.translation.y = 0
        tr.scaling.x = 1.0
        tr.scaling.y = 1.0
        tr.rotation = 0.0
        mat.add_property(Assimp::MATKEY_UVTRANSFORM, tr, semantic: :DIFFUSE)
        break
      end
    }
  end
  mat
}


output_dir = "assimp_output/#{$root_node.name}_#{format}"
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
$wtb.each.each_with_index { |info_f, i|
  info, f = info_f
  ext, _, _ = info
  File::open("#{output_dir}/#{$root_node.name}_#{"%02d"%i}#{ext}", "wb") { |f2|
    f.rewind
    f2.write(f.read)
  }
}
GC.start
postprocess = [:FlipWindingOrder]
#if format == "obj"
  postprocess.push :FlipUVs
#end
$scene.root_node.each_node { |n| puts n.name }
$scene.export(format, output_dir+"/#{$root_node.name}.#{extension}", preprocessing: postprocess)
