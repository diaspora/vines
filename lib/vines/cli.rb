module Vines
  # The command line application that's invoked by the `vines` binary included
  # in the gem. Parses the command line arguments to create a new server
  # directory, and starts and stops the server.
  class CLI
    COMMANDS = %w[start stop restart cert]

    def self.start
      self.new.start
    end

    # Run the command line application to parse arguments and run sub-commands.
    # Exits the process with a non-zero return code to indicate failure.
    #
    # Returns nothing.
    def start
      opts = parse(ARGV)
      command = Command.const_get(opts[:command].capitalize).new
      begin
        command.run(opts)
      rescue SystemExit
        # do nothing
      end
    end

    private

    # Parse the command line arguments and run the matching sub-command
    # (e.g. init, start, stop, etc).
    #
    # args - The ARGV array provided by the command line.
    #
    # Returns nothing.
    def parse(args)
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: vines [options] #{COMMANDS.join('|')}"

        opts.separator ""
        opts.separator "Daemon options:"

        opts.on('-d', '--daemonize', 'Run daemonized in the background') do |daemonize|
          options[:daemonize] = daemonize
        end

        options[:log] = 'log/vines.log'
        opts.on('-l', '--log FILE', 'File to redirect output (default: log/vines.log)') do |log|
          options[:log] = log
        end

        options[:pid] = 'pid/vines.pid'
        opts.on('-P', '--pid FILE', 'File to store PID (default: pid/vines.pid)') do |pid|
          options[:pid] = pid
        end

        opts.separator ""
        opts.separator "Common options:"

        opts.on('-h', '--help', 'Show this message') do |help|
          options[:help] = help
        end

        opts.on('-v', '--version', 'Show version') do |version|
          options[:version] = version
        end
      end

      begin
        parser.parse!(args)
      rescue
        puts parser
        exit(1)
      end

      if options[:version]
        puts Vines::VERSION
        exit
      end

      if options[:help]
        puts parser
        exit
      end

      command = args.shift
      unless COMMANDS.include?(command)
        puts parser
        exit(1)
      end

      options.tap do |opts|
        opts[:args]    = args
        opts[:command] = command
        opts[:config]  = File.expand_path("conf/config.rb")
        opts[:pid]     = File.expand_path(opts[:pid])
        opts[:log]     = File.expand_path(opts[:log])
        if defined? AppConfig
          opts[:config] = "vines/config/diaspora"
        end
      end
    end
  end
end
