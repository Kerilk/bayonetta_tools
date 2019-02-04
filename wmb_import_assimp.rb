#!ruby
require 'assimp-ffi'
require 'optparse'
require 'set'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta

$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_import_assim.rb target_file source_file [options]"

  opts.on("-bFILE", "--bone-map=FILE", "Bone map") do |bone_map|
    $options[:bone_map] = bone_map
  end

  opts.on("-u", "--update-bones", "Update recognized bone positions") do |update_bones|
    $options[:update_bones] = update_bones
  end

#  opts.on("-t", "--[no-]import-textures", "Import textures also") do |import_textures|
#    $options[:import_textures] = import_textures
#  end

  opts.on("-t", "--[no-]transform-meshes", "Apply node transformation to meshes, conflicts with --group-batch-by-name") do |transform|
    $options[:transform] = transform
    $options[:group] = false
  end

  opts.on("--swap-mesh-y-z", "Use to swap the mesh if it is not aligned to the skeleton") do |swap|
    $options[:swap] = swap
  end

  opts.on("--[no-]sort-bones", "Sorts the bone alphanumerically, WARNING: may cause issue if the order doesn't respect the hierarchy!") do |sort|
    $options[:sort] = sort
  end

  opts.on("-o", "--[no-]overwrite", "Overwrite destination files") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("-g", "--[no-]group-batch-by-name", "Try grouping batches using their names, conflicts with --transform-meshes") do |group|
    $options[:group] = group
    $options[:transform] = false
  end

  opts.on("-f", "--filter-bones=REJECT_LIST", "Don't import all bones") do |filter_bones|
    $options[:filter_bones] = eval(filter_bones)
  end

  opts.on("-a", "--[no-]auto-map", "Auto map bones") do |auto_map|
    $options[:auto_map] = auto_map
  end

  opts.on("-s", "--[no-]list-skeleton", "Display a the skeleton") do |skeleton|
    $options[:skeleton] = skeleton
  end

  opts.on("-l", "--[no-]list", "List source content") do |list|
    $options[:list] = list 
  end

  opts.on("-v", "--[no-]verbose", "Enable logging") do |verbose|
    $options[:verbose] = verbose
  end

  opts.on("-r", "--[no-]use-root-bone", "Use the skeleton root as a bone") do |root|
    $options[:root] = root
  end

  opts.on("--[no-]print-transform", "Print transform matrix when listing") do |print|
    $options[:print_transform] = print
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

$mesh_prefix = /mesh_(\d\d)_/
$batch_prefix = /batch_(\d\d)_/
$bone_prefix = /bone_(\d\d\d)/
$skeleton_prefix = /skeleton/

target = ARGV[0]
source = ARGV[1]

if $options[:list]

  source = target unless source

  scene = Assimp::import_file(source, flags: [:JoinIdenticalVertices, :CalcTangentSpace])

  puts "Found #{scene.num_meshes} meshes."
  puts "Found #{scene.num_textures} embedded textures."
  puts "Found #{scene.num_materials} materials."

  scene.root_node.each_node_with_depth { |n, d|
    puts "  "*d + n.name + (n.num_meshes > 0 ? " (#{n.num_meshes} mesh#{n.num_meshes > 1 ? "es" : ""})" : "")
    puts n.transformation if $options[:print_transform]
  }
  puts "-----------------------------------------------"
  scene.meshes.each { |m|
    puts m.name
    puts "num_vertices: #{m.num_vertices}"
    puts "num_faces: #{m.num_faces}"
    puts "num_bones: #{m.num_bones}"
    m.bones.each { |b|
      puts "  "+b.name
    }
    puts "normals: #{!m[:normals].null?}"
    puts "tangents: #{!m[:tangents].null?}"
    puts "bitangents: #{!m[:bitangents].null?}"
    m.colors.each_with_index { |c, i|
      puts "color #{i}" if c
    }
    m.texture_coords.each_with_index { |t, i|
      puts "uv #{i} (#{m.num_uv_components[i]})" if t
    }
  }
  exit
end

def get_used_bone_set(scene)
  known_bones = Set::new
  scene.meshes.each { |m|
    m.bones.each { |b|
      known_bones.add(b.name)
    }
  }
  known_bones
end

def find_skeleton(scene)

  known_bones = get_used_bone_set(scene)

  raise "Model uses no bones!" if known_bones.size == 0

  skeleton = nil
  potential_roots = nil

  Assimp::Node.define_method(:eql?) do |other|
      self.class == other.class &&
      self.pointer == other.pointer
  end

  Assimp::Node.define_method(:hash) do
      self.pointer.address.hash
  end

  scene.root_node.each_node { |n|
    if known_bones.include?(n.name)
      potential_roots = n.ancestors unless potential_roots
      potential_roots &= n.ancestors
    end
  }

  Assimp::Node.remove_method :eql?
  Assimp::Node.remove_method :hash

  skeleton = potential_roots.find { |n| n.name.match($skeleton_prefix) }

  if !skeleton
    potential_roots.reverse.each { |n|
      if n.children.find { |c| c.name.match($bone_prefix) }
        skeleton = n
        break
      end
    }
  end

  if !skeleton
    skeleton = potential_roots.first
  end

  skeleton

end

if $options[:skeleton]

  source = target unless source

  scene = Assimp::import_file(source, flags: [:JoinIdenticalVertices, :CalcTangentSpace])

  skeleton = find_skeleton(scene)
  skeleton.each_node_with_depth { |n, d|
    puts "  "*d + n.name
  }
  exit
end

def scene_bones(scene)
   skeleton = find_skeleton(scene)
   bones = []
   skeleton.children.each { |c|
     bones += c.each_node_with_depth.collect.to_a
   }
#this doesn't always work
   bones.sort! { |(n1, d1), (n2, d2)|
     n1.name <=> n2.name
   } if $options[:sort]
   bones.collect! { |n, d| n }
   bones = [skeleton] + bones if $options[:root]
   bones
end

def find_bone_mapping(wmb, scene)
  tt1 = wmb.bone_index_translate_table.table

  common_mapping = {}

  global_bone_names = tt1.keys
  scene_bones = scene_bones(scene)

  if $options[:auto_map]
    scene_bones.each { |n|
      data = n.name.match($bone_prefix)
      if data
        bone_number = data[1].to_i
        if global_bone_names.include?(bone_number)
          common_mapping[n.name] = bone_number
        end
      end
    }
  elsif $options[:bone_map]
    common_mapping.merge! YAML::load_file( $options[:bone_map] )
  else
    common_mapping = {}
  end

  mapping = {}
  scene_bones.each { |n|
    mapping[n.name] = tt1[common_mapping[n.name]]
  }
  node_mapping = scene_bones.collect { |n| [n.name, n] }.to_h
  [mapping, common_mapping, node_mapping]
end

def get_new_bones(wmb, mapping, node_mapping)
  bones_wmb = wmb.get_bone_structure
  if $options[:update_bones]
    raise "Option --update-bones not yet implemented!"
  end

  mapping[-1] = -1
  missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| k }

  if $options[:filter_bones]
    missing_bones -= $options[:filter_bones]
  end

  new_bone_index = bones_wmb.size
  new_bone_indexes = []

  missing_bones.each { |bi|
    mapping[bi] = new_bone_index
    new_bone_indexes.push(new_bone_index)
    p = node_mapping[bi].world_transformation * Assimp::Vector3D::new
    pos = Position::new
    pos.x, pos.y, pos.z = p.x, p.y, p.z
    b = Bone::new(pos)
    b.index = new_bone_index
    parent_name = nil
    if node_mapping[bi].parent
      parent_name = node_mapping[bi].parent.name
      parent_name = nil unless node_mapping.include?(parent_name)
    end
    b.parent = bones_wmb[mapping[parent_name]] if parent_name
    b.symmetric = -1
    b.flag = 5
    bones_wmb.push b
    new_bone_index += 1
  }
  [bones_wmb, missing_bones, new_bone_indexes]
end

def update_translate_table(wmb, common_mapping, missing_bones, new_bone_indexes)
  missing_bones_count = new_bone_indexes.length
  raise "Too many bones to add!" if missing_bones_count > 0x100
  (align(missing_bones_count, 0x10) - missing_bones_count).times {
    new_bone_indexes.push(0xfff)
  }

  tt = wmb.bone_index_translate_table.table
  used_indexes = tt.keys
  start_index = nil

  (0x250..(0x1000-new_bone_indexes.size)).step(0x10) { |s_index|
    if (used_indexes & (s_index..(s_index+new_bone_indexes.size)).to_a) == []
      start_index = s_index
      break
    end
  }
  raise "No room available in translate table!" unless start_index
  new_tt = wmb.bone_index_translate_table.table.dup
  new_bone_indexes.each_with_index { |ind, i|
    new_tt[i+start_index] = ind
    common_mapping[missing_bones[i]] = i + start_index if i < missing_bones.length && missing_bones[i]
  }
  wmb.bone_index_translate_table.table = new_tt
  if wmb.bone_symmetries
    (-missing_bones_count..-1).each { |i|
      symmetric = common_mapping[wmb.bone_symmetries[i]]
      symmetric = -1 unless symmetric
      wmb.bone_symmetries[i] = symmetric
    }
  end
end

def merge_bones(wmb, scene)
  mapping, common_mapping, node_mapping = find_bone_mapping(wmb, scene)

  bones_wmb, missing_bones, new_bone_indexes = get_new_bones(wmb, mapping, node_mapping)

  wmb.set_bone_structure(bones_wmb)

  update_translate_table(wmb, common_mapping, missing_bones, new_bone_indexes)

  [common_mapping, mapping]
end

def get_mesh_mapping(scene)
  if $options[:group]
    mesh_mapping = Hash::new { |h, k| h[k] = [] }
    scene.meshes.sort { |m1, m2| m1.name <=> m2.name }.each { |m|
      data = m.name.match($batch_prefix)
      if data
        mesh_name = m.name.gsub(data[0], "")
      else
        mesh_name = m.name
      end
      data = mesh_name.match(/_(\d\d)/)
      if data
        mesh_name = mesh_name.gsub(data[0], "")
      end
      mesh_mapping[mesh_name].push(m)
    }
  else
    mesh_nodes = scene.root_node.each_node.select{ |n| n.children.find { |c| c.num_meshes > 0 } }.to_a
    mesh_mapping = mesh_nodes.collect { |n|
      batches = []
      n.children.each { |c|
        batches += c.meshes
      }
      [n, batches.collect{ |num| scene.meshes[num] }]
    }.sort { |(n1, _), (n2, _)| n1.name <=> n2.name }.to_h
  end
  mesh_mapping
end

def create_new_meshes(wmb, mesh_mapping)
  new_meshes = mesh_mapping.each_with_index.collect { |(m, _), i|
    new_mesh = WMBFile::Mesh::new
    if $options[:group]
      mesh_name = m
    else
      mesh_name = m.name
    end
    data = mesh_name.match($mesh_prefix)
    if data
      name = mesh_name.gsub(data[0], "")
      mesh_name = name if name != ""
    end
    new_mesh.header.name = mesh_name
    new_mesh.header.id = i + wmb.header.num_meshes
    new_mesh
  }
end

def set_fields(wmb, bone_mapping, batch, new_indices, transform_matrix)
  bone_refs = {}
  bone_refs = batch.bones.sort { |b1, b2|
      b1.name <=> b2.name
    }.collect(&:name).uniq.each_with_index.collect { |b, i|
      [b, i]
    }.to_h
  fields = wmb.get_vertex_fields

  _, rotation, _ = transform_matrix.decompose

  fields.each do |field|
  case field
  when :position
    vertices = batch.vertices
    new_indices.each_with_index { |target_index, index|
      p = Position::new
      o_p = vertices[index]
      o_p = transform_matrix * o_p
      p.x = o_p.x
      p.y = o_p.y
      p.z = o_p.z
      wmb.set_vertex_field(field, target_index, p)
    }
  when :normal
    normals = batch.normals
    new_indices.each_with_index { |target_index, index|
      n = Normal::new
      o_n = normals[index]
      o_n = rotation * o_n
      n.x = o_n.x
      n.y = o_n.y
      n.z = o_n.z
      wmb.set_vertex_field(field, target_index, n)
    }
  when :tangents
    tangents = batch.tangents
    bitangents = batch.bitangents
    normals = batch.normals
    new_indices.each_with_index { |target_index, index|
      t = Tangents::new
      o_t = tangents[index]
      if o_t
        o_t = rotation * o_t
        o_n = normals[index]
        o_n = rotation * o_n
        o_b = bitangents[index]
        o_b = rotation * o_b
        n_o_b = (o_n ^ o_t)
        if (n_o_b + o_b).length > 1
          s = -1.0
        else
          s = 1.0
        end
        if o_t.x.nan? || o_t.y.nan? || o_t.z.nan?
          t.set(0, 0, 0, 1)
        else
          t.set(o_t.x, o_t.y, o_t.z, s)
        end
      else
        warn "Invalid mapping(tangents not computable) for batch: #{batch.name}!"
        t.set(0, 0, 0, 1)
      end
      wmb.set_vertex_field(field, target_index, t)
    }
  when :mapping, :mapping2, :mapping3, :mapping4, :mapping5
    mapping_index = 0
    mapping_index = 1 if field == :mapping2
    mapping_index = 2 if field == :mapping3
    mapping_index = 3 if field == :mapping4
    mapping_index = 4 if field == :mapping5
    mapping_index = 0 if batch.num_uv_components[mapping_index] < 2
    texture_coords = batch.texture_coords[mapping_index]
    raise "No texture coordinate found!" unless texture_coords
    new_indices.each_with_index { |target_index, index|
      m = Mapping::new
      o_m = texture_coords[index]
      m.u = o_m.x
      m.v = o_m.y
      wmb.set_vertex_field(field, target_index, m)
    }
  when :color, :color2
    color_index = 0
    color_index = 1 if field == :color2
    colors = batch.colors[color_index]
    if colors
      new_indices.each_with_index { |target_index, index|
        c = Color::new
        o_c = colors[index]
        c.r = (o_c.r * 255.0).round.clamp(0, 255)
        c.g = (o_c.g * 255.0).round.clamp(0, 255)
        c.b = (o_c.b * 255.0).round.clamp(0, 255)
        c.a = (o_c.a < 0 ? 255 : (c.a * 255.0).round.clamp(0, 255))
        wmb.set_vertex_field(field, target_index, c)
      }
    else
      c = Color::new
      c.r = 0xc0
      c.g = 0xc0
      c.b = 0xc0
      c.a = 0xff
      new_indices.each_with_index { |target_index, _|
        wmb.set_vertex_field(field, target_index, c)
      }
    end
  when :bone_infos
    bone_infos = new_indices.size.times.collect {
      []
    }
    batch.bones.each { |bone|
      bone_index = bone_refs[bone.name]
      bone.weights.each { |vtxweight|
        vertex_id = vtxweight.vertex_id
        weight = vtxweight.weight
        bone_infos[vertex_id].push [bone_index, weight]
      }
    }
    bone_infos = bone_infos.collect { |bone_info|
      b_i = bone_info.sort { |(_, w1), (_, w2)| w1 <=> w2 }.reverse.first(4).reject { |_, w| w <= 0.0 }
      if b_i.length == 0
        warn "Invalid rigging for batch: #{batch.name}, orphan vertex!"
      else
        sum = b_i.reduce(0.0) { |memo, (_, w)| memo + w }
        b_i.collect! { |ind, w| [ind, (w*255.0/sum).round.clamp(0, 255)] }
        sum = b_i.reduce(0) { |memo, (_, w)| memo + w }
        if sum != 255
          diff = 255 - sum
          b_i.first[1] += diff
        end
      end
      b_i
    }
    
    new_indices.each_with_index { |target_index, index|
      bi = BoneInfos::new
      bi.set_indexes_and_weights(bone_infos[index])
      wmb.set_vertex_field(field, target_index, bi)
    }
  else
    raise "Unknow field in wmb file #{field.inspect}!"
  end
  end
  bone_refs
end

def merge_geometry(wmb, scene, bone_mapping)
  mesh_mapping = get_mesh_mapping(scene)

  new_meshes = create_new_meshes(wmb, mesh_mapping)

  vertex_types = wmb.get_vertex_types

  mesh_mapping.each_with_index { |(n, batches), i|
    if $options[:transform]
      matrix = n.world_transformation
    else
      matrix = Assimp::Matrix4x4::identity
    end
    if $options[:swap]
      rot = Assimp::Matrix4x4::new
      rot.a1 = 1.0
      rot.b3 = -1.0
      rot.c2 = 1.0
      rot.d4 = 1.0
      matrix = rot * matrix
    end

    batches.each_with_index { |batch, j|
      first_vertex_index = wmb.vertexes.length

      num_vertices = batch.num_vertices
      indices = (0...num_vertices)
      new_indices = (first_vertex_index...(first_vertex_index + num_vertices)).to_a

      wmb.vertexes += num_vertices.times.collect {
        vertex_types[0]::new
      }
      if wmb.vertexes_ex_data
        wmb.vertexes_ex_data += num_vertices.times.collect {
          vertex_types[1]::new
        }
      end

      wmb.header.num_vertexes += num_vertices

      bone_refs = set_fields(wmb, bone_mapping, batch, new_indices, matrix)

      b = WMBFile::Batch::new
      b.header.material_id = wmb.header.num_materials + batch.material_index
      b.header.mesh_id = new_meshes[i].header.id
      indice_array = []
      batch.faces.each { |f|
        indice_array += f.indices.collect { |ind| new_indices[ind] }
      }
      b.header.num_indices = indice_array.length
      b.indices = indice_array
      b.recompute_from_absolute_indices
      b.bone_refs = bone_refs.collect { |name, _| bone_mapping[name] }
      b.num_bone_ref = b.bone_refs.length
      new_meshes[i].batches.push b
      new_meshes[i].header.num_batch += 1
    }
  }
  wmb.meshes += new_meshes
  wmb.header.num_meshes += new_meshes.length

end

def get_new_tex_list(scene)
  texture_set = Set::new
  scene.materials.each { |m|
    m.properties.each { |p|
      if p.key == Assimp::MATKEY_TEXTURE
        texture_set.add p.data
      end
    }
  }
  texture_set.to_a.sort
end

def merge_materials(wmb, scene, tex)
  old_tex_count = tex.each.count
  new_tex_list = get_new_tex_list(scene)
  new_tex_map = new_tex_list.each_with_index.collect { |t, i| [t, i+old_tex_count] }.to_h

  mat_offset = wmb.materials_offsets.last + wmb.materials.last.size
  new_materials = []
  new_materials_offsets = []
  scene.materials.each_with_index { |mat, i|
    new_materials_offsets.push(mat_offset + i*0x124)
    m = WMBFile::Material::new
    m.type = 0x0
    m.flag = 0x0
    m.material_data = [0x0]*(0x120/4)
    mat.properties.select { |p|
        p.key == Assimp::MATKEY_TEXTURE
      }.collect { |p|
        new_tex_map[p.data]
      }.each_with_index { |tex, j|
        m.material_data[j] = tex
      }
    m.material_data[0] = (m.material_data[0] ? m.material_data[0] : 0x80000000)
    m.material_data[1] = (m.material_data[1] ? m.material_data[1] : 0x80000000)
    new_materials.push(m)
  }
  wmb.header.num_materials += new_materials.size
  wmb.materials += new_materials
  wmb.materials_offsets += new_materials_offsets

  new_tex_list
end

def add_textures(tex, path, new_tex_list)
  new_tex_list.each { |tex_path|
    extension = File.extname(tex_path)
    if extension.downcase != ".dds"
      old_tex_path = File.join(path, tex_path)
      tex_path = File.join(path, File.join(File.dirname(tex_path), File.basename(tex_path,extension)))+".dds"
      `convert -define dds:compression=dxt5 "#{old_tex_path}" "#{tex_path}"`
    else
      tex_path = File.join(path, tex_path)
    end
    tex.push File::new(tex_path, "rb")
  }
end

raise "Invalid file #{target}" unless File::file?(target)
raise "Invalid file #{source}" unless File::file?(source)

Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")

wmb = WMBFile::load(target)

tex_file_name = target.gsub(/wmb\z/,"wtb")
tex = WTBFile::new(File::new(tex_file_name, "rb"))

if $options[:verbose]
  log = Assimp::LogStream::stderr
  log.attach
  Assimp::LogStream::verbose(1)
end

scene = Assimp::import_file(source, flags: [:JoinIdenticalVertices, :CalcTangentSpace, :FlipWindingOrder, :Triangulate, :FlipUVs])


common_mapping, bone_mapping = merge_bones(wmb, scene)

merge_geometry(wmb, scene, bone_mapping)

new_tex_list = merge_materials(wmb, scene, tex)

add_textures(tex, File.dirname(source), new_tex_list)

wmb.recompute_relative_positions
wmb.recompute_layout

File::open("wmb_output/#{File::basename(source,File::extname(source))}_#{File::basename(target,".wmb")}_bone_map.yaml", "w") { |f|
  f.write YAML::dump(common_mapping)
}

if $options[:overwrite]
  wmb.__dump(target)
  tex.dump(tex_file_name)
else
  wmb.__dump("wmb_output/"+File.basename(target))
  tex.dump("wtb_output/"+File.basename(tex_file_name))
end
