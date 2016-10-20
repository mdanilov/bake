require 'bake/toolchain/colorizing_formatter'
require 'common/options/parser'
require 'bake/toolchain/gcc'

module Bake

  class BakeqacOptions < Parser
    attr_reader :rcf, :acf, :qacdata, :qacstep, :qac_home  # String
    attr_reader :c11, :c14, :qacfilter, :qacnoformat, :qacunittest, :qacdoc # Boolean
    attr_reader :cct # Array
    attr_reader :qacretry # int

    def initialize(argv)
      super(argv)

      @main_dir = nil
      @cVersion = ""
      @c11 = false
      @acf = nil
      @rcf = nil
      @cct = []
      @default = nil
      @qacdata = ".qacdata"
      @qacstep = nil
      @qacfilter = true
      @qacnoformat = false
      @qacunittest = false
      @qacretry = 0
      @qacdoc = false

      add_option(["-b", ""      ], lambda { |x| setDefault(x)                })
      add_option(["-a"          ], lambda { |x| Bake.formatter.setColorScheme(x.to_sym) })
      add_option(["-m"          ], lambda { |x| set_main_dir(x)              })
      add_option(["--c++11"     ], lambda {     @cVersion = "-c++11"         })
      add_option(["--c++14"     ], lambda {     @cVersion = "-c++14"         })
      add_option(["--cct"       ], lambda { |x| @cct << x.gsub(/\\/,"/")     })
      add_option(["--rcf"       ], lambda { |x| @rcf = x.gsub(/\\/,"/")      })
      add_option(["--acf"       ], lambda { |x| @acf = x.gsub(/\\/,"/")      })
      add_option(["--qacdata"   ], lambda { |x| @qacdata = x.gsub(/\\/,"/")  })
      add_option(["--qacstep"   ], lambda { |x| @qacstep = x                 })
      add_option(["--qacfilter" ], lambda { |x| @qacfilter = (x == "on")     })
      add_option(["--qacretry"  ], lambda { |x| @qacretry = x.to_i           })
      add_option(["--qacnoformat" ], lambda { @qacnoformat = true            })
      add_option(["--qacunittest" ], lambda { @qacunittest = true            })
      add_option(["--qacdoc"    ], lambda { @qacdoc = true                    })
      add_option(["-h", "--help"], lambda {     usage; ExitHelper.exit(0)    })
      add_option(["--version"   ], lambda {     Bake::Version.printBakeqacVersion; ExitHelper.exit(0)    })

    end

    def usage
      puts "\nUsage: bakeqac [options]"
      puts " --c++11          Use C++11 rules, available for GCC 4.7 and higher."
      puts " --c++14          Use C++14 rules, available for GCC 4.9 and higher."
      puts " --cct <file>     Set a specific compiler compatibility template, otherwise $(QAC_HOME)/config/cct/<platform>.ctt will be used. Can be defined multiple times."
      puts " --rcf <file>     Set a specific rule config file, otherwise qac.rcf will be searched up to root. If not found, $(QAC_HOME)/config/rcf/mcpp-1_5_1-en_US.rcf will be used."
      puts " --acf <file>     Set a specific analysis config file, otherwise $(QAC_HOME)/config/acf/default.acf will be used."
      puts " --qacdata <dir>  QAC writes data into this folder. Default is <working directory>/.qacdata."
      puts " --qacstep admin|analyze|view   Steps can be ORed. Per default all steps will be executed."
      puts " --qacfilter on|off   If off, output will be printed immediately and unfiltered, default is on to reduce noise."
      puts " --qacretry <seconds>   If build or result step fail due to refused license, the step will be retried until timeout. Works only if qacfilter is not off."
      puts " --qacdoc         Print link to HTML help page for every warning if found."
      puts " --version        Print version."
      puts " -h, --help       Print this help."
      puts "Note: all parameters from bake apply also here. Note, that --rebuild and --compile-only will be added to the internal bake call automatically."
      puts "Note: works only for GCC 4.1 and above"
    end

    def setDefault(x)
      if (@default)
        Bake.formatter.printError("Error: '#{x}' not allowed, '#{@default}' already set.")
        ExitHelper.exit(1)
      end
      @default = x
    end

    def check_valid_dir(dir)
     if not File.exists?(dir)
        Bake.formatter.printError("Error: Directory #{dir} does not exist")
        ExitHelper.exit(1)
      end
      if not File.directory?(dir)
        Bake.formatter.printError("Error: #{dir} is not a directory")
        ExitHelper.exit(1)
      end
    end

    def set_main_dir(dir)
      check_valid_dir(dir)
      @main_dir = File.expand_path(dir.gsub(/[\\]/,'/'))
    end

    def searchRcfFile(dir)
      rcfFile = dir+"/qac.rcf"
      return rcfFile if File.exist?(rcfFile)

      parent = File.dirname(dir)
      return searchRcfFile(parent) if parent != dir

      return nil
    end

    def parse_options(bakeOptions)
      parse_internal(true, bakeOptions)
      set_main_dir(Dir.pwd) if @main_dir.nil?

      if not ENV["QAC_HOME"]
        Bake.formatter.printError("Error: specify the environment variable QAC_HOME.")
        ExitHelper.exit(1)
      end

      if !@qacstep.nil?
        @qacstep.split("|").each do |s|
          if not ["admin", "analyze", "view"].include?s
            Bake.formatter.printError("Error: incorrect qacstep name.")
            ExitHelper.exit(1)
          end
        end
      end

      @qac_home = ENV["QAC_HOME"].gsub(/\\/,"/")
      @qac_home = qac_home[0, qac_home.length-1] if qac_home.end_with?"/"

      if @cct.empty?
        gccVersion = Bake::Toolchain::getGccVersion
        if gccVersion.length < 2
          Bake.formatter.printError("Error: could not determine GCC version.")
          ExitHelper.exit(1)
        end

        if RUBY_PLATFORM =~ /mingw/
          plStr = "w64-mingw32"
        elsif RUBY_PLATFORM =~ /cygwin/
          plStr = "pc-cygwin"
        else
          plStr = "generic-linux"
        end

        while (@cct.empty? or gccVersion[0]>=5)
          @cct = [qac_home + "/config/cct/GNU_GCC-g++_#{gccVersion[0]}.#{gccVersion[1]}-i686-#{plStr}-C++#{@cVersion}.cct"]
          break if File.exist?@cct[0]
          @cct = [qac_home + "/config/cct/GNU_GCC-g++_#{gccVersion[0]}.#{gccVersion[1]}-x86_64-#{plStr}-C++#{@cVersion}.cct"]
          break if File.exist?@cct[0]
          if gccVersion[1]>0
            gccVersion[1] -= 1
          else
            gccVersion[0] -= 1
            gccVersion[1] = 20
          end
        end
      end

      if @acf.nil?
        @acf = qac_home + "/config/acf/default.acf"
      end

      if @rcf.nil?
        rfcInDir = searchRcfFile(@main_dir)
        if rfcInDir
          @rcf = rfcInDir.gsub(/[\\]/,'/')
        else
          @rcf  = qac_home + "/config/rcf/mcpp-1_5_1-en_US.rcf"
        end
      end

    end


  end

end
