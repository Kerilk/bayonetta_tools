Gem::Specification.new do |s|
  s.name = 'pgtools'
  s.version = "1.0.0"
  s.author = "Brice Videau"
  s.email = "brice.videau@gmail.com"
  s.homepage = "https://github.com/kerilk/bayonetta_tools"
  s.summary = "Library and utilities to manipulate PlatinumGames files."
  s.description = "Those are tha basic tools required to work on PlatinumGames files and mod them."
  s.files = Dir[ 'libbin.gemspec', 'LICENSE', 'lib/**/*.rb', 'lib/**/*.yaml', 'bin/*' ]
  s.bindir = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.license = 'BSD-2-Clause'
  s.required_ruby_version = '>= 2.3.0'
  s.add_dependency 'libbin', '~> 2', '>=2.0.0'
  s.add_dependency 'zstd-ruby', '~> 1', '>=1.5.0'
  s.add_dependency 'assimp-ffi', '~> 0.1',  '>=0.1.7'
end
