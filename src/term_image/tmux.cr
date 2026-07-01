module TermImage
  module Tmux
    extend self

    def wrap(sequence : Bytes) : String
      String.build do |io|
        io << "\ePtmux;"
        sequence.each do |byte|
          io.write_byte(0x1b_u8) if byte == 0x1b
          io.write_byte(byte)
        end
        io << "\e\\"
      end
    end
  end
end
