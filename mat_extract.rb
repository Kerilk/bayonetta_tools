#!ruby
puts ARGV[0]
i = 0
HEADER_SIZE = 4
TEXTURE_SIZE = 4
FLOAT_DATA_SIZE = 4 * 4
Dir.chdir ARGV[0] do
	names = Dir.entries(".")
	names.sort!
	File.open("#{ARGV[0].split(".").first}.csv", "w") do |fout|
		names.each { |fname|
			next if File.directory?(fname)
			next unless File.extname(fname) == ".mat"
			File.open(fname, "rb") { |f|
				size = f.size
				puts "#{fname} #{size}"
				code = f.read(2)
				code = code.unpack("S").first
				float_size = size - HEADER_SIZE - TEXTURE_SIZE * (code == 0x34 ? 2 : 1)
				float_size = (float_size / FLOAT_DATA_SIZE) * FLOAT_DATA_SIZE
				texture_number = (size - HEADER_SIZE - float_size) / TEXTURE_SIZE
				puts texture_number
				fout.write "#{code & 0xff},"
				fout.write ("%02X" % (code & 0xff)) + ","
				fout.write ("%08b" % (code & 0xff)) + ","
				fout.write fname.split(".").first + "_" + ("%02d" % i) +","
				fout.write ("%X" % size) + ","
				fout.write ("%04X" % code) + ","
				fout.write ("%04X" % f.read(2).unpack("S").first) + ","
				fout.write "#{texture_number},"
				fout.write "," #valid textures
				raise "Too many textures!" if texture_number > 5
				5.times { |j|
					if j < texture_number
						fout.write ("%02X" % f.read(1).unpack("C").first) + ","
						tflag  = f.read(1).unpack("C").first
						t2flag = f.read(2).unpack("S").first
						if t2flag == 0x8000
							fout.write "nil,"
						else
							fout.write "," #skip texture type
						end
						fout.write ("%02X" % tflag  ) + ","
						fout.write ("%04X" % t2flag ) + ","
					else
						fout.write ",,,,"
					end
				}
				str = f.read
				puts str.length
				floats = str.unpack("F*")
				fout.write floats.join(",")
				fout.puts
			}
			i += 1
		}
	end
end


