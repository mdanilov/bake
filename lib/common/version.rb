module Bake
  class Version
    def self.number
      "2.66.0"
    end

    def self.printBakeVersion(ry = "")
      puts "-- bake#{ry} #{Bake::Version.number}, ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}, platform #{RUBY_PLATFORM} --"
    end

    def self.printBakeryVersion()
      printBakeVersion("ry")
    end

    def self.printBakeqacVersion()
      printBakeVersion("qac")
    end

    def self.printBakecleanVersion()
      printBakeVersion("clean")
    end

    def self.printBakeRtextServiceVersion()
      printBakeVersion("-rtext-service")
    end

    def self.printBakeFormatVersion()
      printBakeVersion("-format")
    end
  end

  expectedRGen = "0.8.2"
  expectedRText = "0.9.0"
  expectedConcurrent = "1.0.5"

  begin
    gem "rgen", "=#{expectedRGen}"
  rescue Exception => e
    puts "Warning: Failed to load rgen #{expectedRGen}, using latest version"
  end

  begin
    gem "rtext", "=#{expectedRText}"
  rescue Exception => e
    puts "Warning: Failed to load rtext #{expectedRText}, using latest version"
  end

  begin
    gem "concurrent-ruby", "=#{expectedConcurrent}"
  rescue Exception => e
    puts "Warning: Failed to load concurrent-ruby #{expectedConcurrent}, using latest version"
  end

end
