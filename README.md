# bayonetta_tools

Some scripts I had to create in order to analyze Bayonetta file structure.

You will need some packages especially for the importer.
```bash
sudo apt install ruby ruby-dev git build-essential zlib1g-dev libassimp-dev imagemagick
```
You will need the nokogiri, libbin and assimp-ffi gems installed.
```bash
gem install --user-install nokogiri libbin assimp-ffi
```
Additional gem may be needed for some tools, like `zstd-ruby` or `oodle-kraken-ruby` for Astral Chain or Bayonetta 3 archive decompression.
