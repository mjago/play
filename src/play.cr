require "libao"
include Libao

# Simple Command Line Audio Player with VU-meter in Crystal (0.25.0)
# Requires ffmpeg and libao-dev
# dependencies:
#  shard dependency: github.com/mjago/libao
# Tested on mp3, flac, and m4a files

class Converter
  PIPE        = Process::Redirect::Pipe
  BUFFER_SIZE = 1024 * 8
  RATE        = 44100
  BITS        =    16
  CHANNELS    =     2
  BYTE_FORMAT = LibAO::Byte_Format::AO_FMT_BIG

  def initialize(track)
    @quit = false
    @ch1_data = Channel(Bytes).new
    @ch2_data = Channel(Bytes).new
    @ao = Ao.new
    @ao.set_format(BITS, RATE, CHANNELS, BYTE_FORMAT, matrix = nil)
    @ao.open_live
    @cmd = "/usr/bin/ffmpeg"
    @args = %w(-f wav -acodec pcm_s16le -ac 2 -)
    @args.unshift(track).unshift "-i"
    @strip_header = true
  end

  def play
    spawn do
      count = 0
      while !@quit
        data = @ch1_data.receive
        size = data.bytesize
        @ao.play(data, size)
        @ch2_data.send data
        @quit = true if size == 0
      end
      @ao.exit
    end
  end

  def vu_meter
    spawn do
      last_reading = 0
      bytes = Bytes.new(2)

      while !@quit
        reading = 0
        max = 0
        @ch2_data.receive.each_with_index do |byte, idx|
          case idx % 4
          when 0, 2; bytes[0] = byte
          when 1, 3
            bytes[1] = byte
            int16 = IO::ByteFormat::LittleEndian.decode(Int16, bytes)
            max = int16 if int16 > max
          end
        end
        db = 20.0 * Math.log(max.to_f / Int16::MAX)
        -2.step(to: -100, by: -2) { |n| reading += 1 if db > n }
        title = File.basename(@args[1])
        title = title.size > 12 ? title[0..11] + "..." : title
        clear_meter = "#{" " * (last_reading + title.size + 2)}"
        meter = "\r #{title} #{"*" * reading}\r"
        print clear_meter + meter
        last_reading = reading
      end
    end
    print "\r#{" " * 50}\r"
  end

  def run
    error = IO::Memory.new
    process = Process.new(command: @cmd, args: @args, output: PIPE, error: error)
    bytes = Bytes.new(BUFFER_SIZE)
    play
    vu_meter

    while !@quit
      if !@strip_header
        size = process.output.read bytes
        @ch1_data.send bytes
        @ch2_data.send bytes
        break if size == 0
      else
        process.output.read Bytes.new(1024)
        @strip_header = false
      end
    end
    puts error.to_s if process.wait.exit_code != 0
  end
end

if ARGV.size > 0
  ARGV.each { |track| Converter.new(track).run }
else
  puts "Usage: play track [track2 track3]"
end
