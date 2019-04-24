require 'yaml'
shader_path = ARGV[0]

mats = YAML::load_file("lib/bayonetta/material_database.yaml")

s = <<EOF
typedef struct {
  float dummy;
  float dummy;
  float dummy;
  float dummy;
} f4_ignored_t;

typedef struct {
  float x;
  float dummy;
  float dummy;
  float dummy;
} f4_float_t;

typedef struct {
  float x;
  float y;
  float dummy;
  float dummy;
} f4_float2_t;

typedef struct {
  float x;
  float y;
  float z;
  float dummy;
} f4_float3_t;

typedef struct {
  float x;
  float y;
  float z;
  float w;
} f4_float4_t;

typedef uint32 sampler2D_t <format=hex>;
typedef uint32 samplerCUBE_t <format=hex>;

EOF

broker = <<EOF
        switch(matID) {
EOF

mats.to_a.sort { |a, b| a[0] <=> b [0] }.each { |num, props|
  if props[:shader] && props[:size]
    if props[:size_vertex]
      source_vertex = `./fxc.exe /dumpbin /nologo "#{shader_path}\\#{props[:shader]}.vso"`
      params_vertex = source_vertex.match(/\/\/ Parameters:\r\n(.*)?\/\/ Registers/m)[1]
      registers_vertex = source_vertex.match(/\/\/ Registers:\r\n(.*)?\/\/\r\n/m)[1]

      type_hash_vertex = {}
      params_vertex.lines[1..-3].each { |l|
        type, name = l.match(/\/\/   (.*?) (.*?);/)[1..2]
        type_hash_vertex[name] = type
      }

      register_hash_vertex = {}
      registers_vertex.lines[3..-1].each { |l|
        name, reg, size = l.match(/\/\/   (.*?)\s+(.*?)\s+(\d*)/)[1..3]
        register_hash_vertex[name] = [reg, size]
      }

      parameters_vertex = []
      register_hash_vertex.each { |name, (reg, size)|
        reg_number = reg.match(/c(\d*)/)[1]
        parameters_vertex[reg_number.to_i] = name
      }
      parameters_vertex = parameters_vertex[216..-1]
    end
    source = `./fxc.exe /dumpbin /nologo "#{shader_path}\\#{props[:shader]}.pso"`
    params = source.match(/\/\/ Parameters:\r\n(.*)?\/\/ Registers/m)[1]
    registers = source.match(/\/\/ Registers:\r\n(.*)?\/\/\r\n/m)[1]

    type_hash = {}
    params.lines[1..-3].each { |l|
      type, name = l.match(/\/\/   (.*?) (.*?);/)[1..2]
      type_hash[name] = type
    }

    register_hash = {}
    registers.lines[3..-1].each { |l|
      name, reg, size = l.match(/\/\/   (.*?)\s+(.*?)\s+(\d*)/)[1..3]
      register_hash[name] = [reg, size]
    }

    parameters = []
    samplers = []
    register_hash.each { |name, (reg, size)|
      if reg.match("s")
        if name == "Color_3_sampler"
          ind = samplers.index("Color_2_sampler")
          samplers.insert(ind+1, name)
        else
          samplers.push(name)
        end
      else
        reg_number = reg.match(/c(\d*)/)[1]
        parameters[reg_number.to_i] = name
      end
    }
    parameters = parameters[40..-1]
    s << <<EOF
typedef struct {
EOF
    remaining_size = props[:size] - 4
    samplers.each { |sampler|
      raise "Error not enought room for sampler #{sampler} in material #{num}!" if remaining_size <= 0
      s << <<EOF
  #{type_hash[sampler]}_t #{sampler.gsub("_sampler","")};
EOF
      remaining_size -= 4
    }
    ignored_counter = 0
    while remaining_size % 16 != 0 #add unused sampler
       s << <<EOF
  samplerCUBE_t ignored#{ignored_counter};
EOF
      ignored_counter += 1
      remaining_size -= 4
    end

    if props[:size_vertex]
      remaining_size_vertex = props[:size_vertex]
      parameters_vertex.each { |parameter|
        break if remaining_size_vertex == 0
        raise "Invalid material size_vertex #{props[:size_vertex]} for material #{num}!" if remaining_size_vertex < 0
        if parameter
          s << <<EOF
  f4_#{type_hash_vertex[parameter]}_t #{parameter};
EOF
        else
          s << <<EOF
  f4_ignored_t ingored#{ignored_counter};
EOF
          ignored_counter += 1
        end
        remaining_size_vertex -= 16
        remaining_size -= 16
      }
    end

    parameters.each { |parameter|
      break if remaining_size == 0
      raise "Invalid material size #{props[:size]} for material #{num}!" if remaining_size < 0
      if parameter
        s << <<EOF
  f4_#{type_hash[parameter]}_t #{parameter};
EOF
      else
        s << <<EOF
  f4_ignored_t ingored#{ignored_counter};
EOF
        ignored_counter += 1
      end
      remaining_size -= 16
    }

    s << <<EOF
} mat_#{"%02x" % num}_values_t;

EOF
    broker << <<EOF
        case 0x#{"%02x" % num}:
            mat_#{"%02x" % num}_values_t data;
            break;
EOF
  end
}
broker << <<EOF
        default:
            union {
                uint32  texture <format=hex>;
                float   val;
            } texture[5];
            if ( i == header.numMaterials - 1 ) {
                dataSize =  header.offsetMeshesOffsets - (header.offsetMaterials + materialOffsets[header.numMaterials - 1]) - 24;
            } else {
                dataSize = materialOffsets[i+1] - materialOffsets[i] - 24;
            }
            if (dataSize > 0) {
                float   data[dataSize/4];
            }
            break;
        }
EOF
puts s
puts broker
