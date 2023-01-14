require 'shellwords'

env = `gem environment`
line = env.lines.find { |l| l.match("USER INSTALLATION DIRECTORY") }
if line
  user_installation_library = line.split(":").last.strip
  puts "Found user install directory: #{user_installation_library}"
  add_to_path = "export PATH=#{user_installation_library}/bin:$PATH"
  already = `cat ~/.bashrc`.lines.find { |l|
    l.match /^#{Regexp.escape(add_to_path)}/
  }
  if already
    puts "Directory already in PATH in '~/.bashrc', skiping"
  else
    puts "Adding to '~/.bashrc'"
    `echo #{Shellwords.escape(add_to_path)} >> ~/.bashrc`
  end
end
