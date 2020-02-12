module TestBench
  class Run
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
      if File.exist?(path)
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
