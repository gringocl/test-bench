module TestBench
  class Run
    Error = Class.new(RuntimeError)

    def session
      @session ||= Fixture::Session::Substitute.build
    end
    attr_writer :session

    def exclude_pattern
      @exclude_pattern ||= Defaults.exclude_pattern
    end
    attr_writer :exclude_pattern

    attr_reader :paths

    def initialize(*paths)
      @paths = Array(paths)
    end

    def self.build(*paths, exclude: nil, session: nil, output: nil)
      session ||= TestBench.session

      instance = new(*paths)

      instance.exclude_pattern = exclude unless exclude.nil?

      Fixture::Session.configure(instance, session: session)
      instance.session.output = output unless output.nil?

      instance
    end

    def self.configure(receiver, *paths, attr_name: nil, **args)
      attr_name ||= :run

      instance = build(*paths, **args)
      receiver.public_send(:"#{attr_name}=", instance)
      instance
    end

    def self.call(*paths, session: nil, **args, &block)
      instance = build(*paths, session: session, **args)

      if block.nil?
        instance.()
      else
        instance.() do
          unless session.nil?
            original_session = TestBench.session
            TestBench.session = session
          end

          block.(instance)

        ensure
          unless original_session.nil?
            TestBench.session = original_session
          end
        end
      end
    end

    def call(&block)
      session.start

      if block.nil?
        paths.each do |path|
          path(path)
        end
      else
        block.()
      end

    ensure
      session.finish
    end

    def path(path)
      if File.directory?(path)
        directory(path)
      elsif File.exist?(path)
        file(path)
      else
        raise Error, "Path not found (Path: #{path.inspect})"
      end
    end

    def directory(path)
      glob_pattern = File.join(path, '**/*.rb')

      Dir.glob(glob_pattern).sort.each do |path|
        file(path)
      end
    end

    def file(path)
      unless exclude_pattern.match?(path)
        session.load(path)
      end
    end

    module Defaults
      def self.exclude_pattern
        pattern = ENV.fetch('TEST_BENCH_EXCLUDE_FILE_PATTERN') do
          '_init.rb$'
        end

        Regexp.new(pattern)
      end
    end
  end
end
