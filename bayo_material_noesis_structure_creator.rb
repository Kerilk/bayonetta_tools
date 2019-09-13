require 'yaml'
shader_path = ARGV[0]

mats = YAML::load_file("lib/bayonetta/material_database.yaml")

s = <<EOF
EOF

global_parameters_list = []

mats.to_a.sort { |a, b| a[0] <=> b [0] }.each { |num, props|
  if props[:shader] && props[:size]
    if props[:size_vertex]
      source_vertex = `./fxc.exe /dumpbin /nologo "#{shader_path}\\#{props[:shader]}.vso"`
      params_vertex = source_vertex.match(/\/\/ Parameters:\r\n(.*)?\/\/ Registers/m)[1]
      registers_vertex = source_vertex.match(/\/\/ Registers:\r\n(.*)?\/\/\r\n/m)[1]

      type_hash_vertex = {}
      params_vertex.lines[1..-3].each { |l|
        type, name = l.match(/\/\/   (.*?) (.*?);/)[1..2]
        global_parameters_list.push [name, type] unless type.match("float4x")
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
      global_parameters_list.push [name, type]
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
        samplers.push(name)
      else
        reg_number = reg.match(/c(\d*)/)[1]
        parameters[reg_number.to_i] = name
      end
    }
    parameters = parameters[40..-1]
    remaining_size = props[:size] - 4
    samplers.each { |sampler|
      raise "Error not enought room for sampler #{sampler} in material #{num}!" if remaining_size <= 0
      remaining_size -= 4
    }
    ignored_counter = 0
    while remaining_size % 16 != 0 #add unused sampler
      ignored_counter += 1
      remaining_size -= 4
    end

    if props[:size_vertex]
      remaining_size_vertex = props[:size_vertex]
      parameters_vertex.each { |parameter|
        break if remaining_size_vertex == 0
        raise "Invalid material size_vertex #{props[:size_vertex]} for material #{num}!" if remaining_size_vertex < 0
        if parameter
        else
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
      else
        ignored_counter += 1
      end
      remaining_size -= 16
    }

  end
}
l = global_parameters_list.uniq.collect{ |name, type| [name.downcase, type]}.sort
l.delete(["tex_blend", "float2"])
parameters =  l.reject { |e| e[1].match("sampler") }
samplers = l.select { |e| e[1].match("sampler") }
s << <<EOF
typedef struct bayoMatType_s {
\tbool known;
\tchar * shader_name;
\tshort size;
\tshort sampler_number;
#{samplers.collect { |name, type| "\tshort #{name}; //#{type}"  }.join("\n")}
#{parameters.collect { |name, type| "\tshort #{name}; //#{type}"  }.join("\n")}
} bayoMatType_t;
static void bayoUnsetMatType(bayoMatType_t &mat) {
\tmat.known = false;
\tmat.shader_name = NULL;
\tmat.size = 0;
\tmat.sampler_number = 0;
#{samplers.collect { |name, type| "\tmat.#{name} = -1;"  }.join("\n")}
#{parameters.collect { |name, type| "\tmat.#{name} = -1;"  }.join("\n")}
}
static void bayoSetMatType(bayoMatType_t &mat,
                           char * shader_name,
                           short size,
                           short sampler_number,
#{samplers.collect { |name, type| "                           short #{name}"}.join(",\n")},
#{parameters.collect { |name, type| "                           short #{name}"}.join(",\n")}) {
\tmat.known = true;
\tmat.shader_name = shader_name;
\tmat.size = size;
\tmat.sampler_number = sampler_number;
#{samplers.collect { |name, type| "\tmat.#{name} = #{name};"  }.join("\n")}
#{parameters.collect { |name, type| "\tmat.#{name} = #{name};"  }.join("\n")}
}

bayoMatType_t bayoMatTypes[256];

static void bayoSetMatTypes(void) {
\tfor(int i=0; i<256; i++) {
\t\tbayoUnsetMatType(bayoMatTypes[i]);
\t}
EOF

func_parameters_pos = (samplers+parameters).each_with_index.collect { |(name, _), i| [name, i] }.to_h
func_default_parameters = [-1]*(samplers.size + parameters.size)

mats.to_a.sort { |a, b| a[0] <=> b [0] }.each { |num, props|
  if props[:shader] && props[:size]
    if props[:size_vertex]
      source_vertex = `./fxc.exe /dumpbin /nologo "#{shader_path}\\#{props[:shader]}.vso"`
      params_vertex = source_vertex.match(/\/\/ Parameters:\r\n(.*)?\/\/ Registers/m)[1]
      registers_vertex = source_vertex.match(/\/\/ Registers:\r\n(.*)?\/\/\r\n/m)[1]

      type_hash_vertex = {}
      params_vertex.lines[1..-3].each { |l|
        type, name = l.match(/\/\/   (.*?) (.*?);/)[1..2]
        global_parameters_list.push [name, type] unless type.match("float4x")
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
      global_parameters_list.push [name, type]
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
    remaining_size = props[:size] - 4
    offset = 4

    func_parameters = func_default_parameters.dup
    sampler_number = 0

    samplers.each { |sampler|
      raise "Error not enought room for sampler #{sampler} in material #{num}!" if remaining_size <= 0
      func_parameters[func_parameters_pos[sampler.downcase]] = offset
      offset += 4
      remaining_size -= 4
      sampler_number += 1
    }

    ignored_counter = 0
    while remaining_size % 16 != 0 #add unused sampler
      offset += 4
      ignored_counter += 1
      remaining_size -= 4
    end

    if props[:size_vertex]
      remaining_size_vertex = props[:size_vertex]
      parameters_vertex.each { |parameter|
        break if remaining_size_vertex == 0
        raise "Invalid material size_vertex #{props[:size_vertex]} for material #{num}!" if remaining_size_vertex < 0
        if parameter
          func_parameters[func_parameters_pos[parameter.downcase]] = offset
        else
          ignored_counter += 1
        end
        offset += 16
        remaining_size_vertex -= 16
        remaining_size -= 16
      }
    end

    parameters.each { |parameter|
      break if remaining_size == 0
      raise "Invalid material size #{props[:size]} for material #{num}!" if remaining_size < 0
      if parameter
        func_parameters[func_parameters_pos[parameter.downcase]] = offset
      else
        ignored_counter += 1
      end
      offset += 16
      remaining_size -= 16
    }
    s << <<EOF
\tbayoSetMatType(bayoMatTypes[0x#{"%2x" % num}], #{props[:shader].inspect}, #{props[:size]}, #{sampler_number}, #{func_parameters.join(", ")});
EOF
  end
}
s << <<EOF
}
EOF

puts s
