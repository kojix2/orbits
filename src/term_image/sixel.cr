module TermImage
  module Sixel
    extend self

    def write(output : IO, image : Indexed) : Nil
      output << "\eP0;1q"
      output << %("1;1;#{image.width};#{image.height})
      write_palette(output, image.palette)

      sixel_rows = (image.height + 5) // 6
      sixel_rows.times do |row|
        output << "-" if row > 0
        lines = Hash(UInt8, Bytes).new

        6.times do |bit|
          y = row * 6 + bit
          break if y >= image.height
          image.width.times do |x|
            idx = image.indices[y * image.width + x]
            line = lines[idx] ||= Bytes.new(image.width)
            line[x] |= (1_u8 << bit)
          end
        end

        first_color = true
        lines.keys.sort!.each do |color|
          output << "$" unless first_color
          output << "##{color}"
          write_runs(output, lines[color], image.width)
          first_color = false
        end
      end
      output << "\e\\"
      output.flush
    end

    private def write_palette(output : IO, palette) : Nil
      palette.each_with_index do |rgb, i|
        r = (((rgb >> 16) & 0xff) * 100 // 255).to_i
        g = (((rgb >> 8) & 0xff) * 100 // 255).to_i
        b = ((rgb & 0xff) * 100 // 255).to_i
        output << "##{i};2;#{r};#{g};#{b}"
      end
    end

    private def write_runs(output : IO, line : Bytes, width : Int32) : Nil
      prev = 255_u8
      run = 0
      width.times do |x|
        value = line[x]
        if prev != 255_u8 && value != prev
          write_run(output, run, prev)
          run = 0
        end
        prev = value
        run += 1
      end
      write_run(output, run, prev)
    end

    private def write_run(output : IO, count : Int32, value : UInt8) : Nil
      return if count <= 0
      char = (0x3f + (value & 0x3f)).chr
      if count > 3
        output << "!#{count}#{char}"
      else
        count.times { output << char }
      end
    end
  end
end
