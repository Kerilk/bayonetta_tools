require 'libbin'
require_relative 'bayonetta/linalg'
require_relative 'bayonetta/endianness'
require_relative 'bayonetta/alignment'
require_relative 'bayonetta/bone'
#require_relative 'bayonetta/data_converter'
require_relative 'bayonetta/pkz'
require_relative 'bayonetta/dat'
require_relative 'bayonetta/eff'
require_relative 'bayonetta/wtb'
require_relative 'bayonetta/wmb'
require_relative 'bayonetta/wmb3'
require_relative 'bayonetta/exp'
require_relative 'bayonetta/bxm'
require_relative 'bayonetta/clp'
require_relative 'bayonetta/clh'
require_relative 'bayonetta/clw'
require_relative 'bayonetta/scr'
require_relative 'bayonetta/mot'

module Bayonetta
  include Alignment

  #Platforms
  PC = 1
  WIIU = 2
  XBOX360 = 3
  PS3 = 4
  SWITCH = 5
  PLATFORMS = {
    pc: PC,
    wiiu: WIIU,
    xbox360: XBOX360,
    ps3: PS3,
    switch: SWITCH
  }

  #Games
  BAYONETTA = 1
  BAYONETTA2 = 2
  NIERAUTOMATA = 3
  VANQUISH = 4
  ANARCHY = 5
  GAMES = {
    bayo: BAYONETTA,
    bayo2: BAYONETTA2,
    nier: NIERAUTOMATA,
    vanquish: VANQUISH,
    anarchy: ANARCHY
  }

  #Supported
  SUPPORTED = {
    [BAYONETTA, PC] => true,
    [BAYONETTA, WIIU] => true,
    [BAYONETTA2, WIIU] => true,
    [NIERAUTOMATA, PC] => true,
    [VANQUISH, PC] => true,
    [ANARCHY, XBOX360] => true
  }
end
