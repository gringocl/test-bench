module TestBench
  class Output
    include TestBench::Fixture::Output

    def writer
      @writer ||= Writer::Substitute.build
    end
    attr_writer :writer

    def timer
      @timer ||= Timer::Substitute.build
    end
    attr_writer :timer

    def omit_backtrace_pattern
      @omit_backtrace_pattern ||= Defaults.omit_backtrace_pattern
    end
    attr_writer :omit_backtrace_pattern

    def reverse_backtraces
      instance_variable_defined?(:@reverse_backtraces) ?
        @reverse_backtraces :
        @reverse_backtraces = Defaults.reverse_backtraces
    end
    attr_writer :reverse_backtraces

    def assert_block_depth
      @assert_block_depth ||= 0
    end
    attr_writer :assert_block_depth

    def verbose
      instance_variable_defined?(:@verbose) ?
        @verbose :
        @verbose = Defaults.verbose
    end
    attr_writer :verbose

    def error_count
      @error_count ||= 0
    end
    attr_writer :error_count

    def failure_count
      @failure_count ||= 0
    end
    attr_writer :failure_count

    def file_count
      @file_count ||= 0
    end
    attr_writer :file_count

    def pass_count
      @pass_count ||= 0
    end
    attr_writer :pass_count

    def skip_count
      @skip_count ||= 0
    end
    attr_writer :skip_count

    def test_count
      @test_count ||= 0
    end
    attr_writer :test_count

    def previous_byte_offset
      @previous_byte_offset ||= 0
    end
    attr_writer :previous_byte_offset

    def file_error_counter
      @file_error_counter ||= 0
    end
    attr_writer :file_error_counter

    def errors_by_file
      @errors_by_file ||= {}
    end
    attr_writer :errors_by_file

    attr_accessor :error_details

    attr_accessor :previous_error

    attr_accessor :previous_byte_offset

    def start_run
      timer.start
    end

    def finish_run(result)
      unless errors_by_file.empty?
        writer
          .escape_code(:bold)
          .escape_code(:red)
          .text('Error Summary:')
          .escape_code(:reset_intensity)
          .escape_code(:reset_fg)
          .newline

        errors_by_file.each do |path, errors|
          writer
            .text(errors.to_s.rjust(4, ' '))
            .text(": #{path}")
            .newline
        end

        writer.newline
      end

      return unless timer.running?

      elapsed_time = timer.stop

      failed = !result

      if elapsed_time.nonzero?
        tests_per_second = test_count / elapsed_time
      end

      if failed
        writer.escape_code(:red)
      end

      writer
        .text("Finished running #{numeric_label(file_count, 'file')}")
        .newline
        .text("Ran %s in %.3fs (%.1f tests/second)" % [
          numeric_label(test_count, 'test'),
          elapsed_time,
          tests_per_second || 0])
        .newline

      if pass_count.nonzero? && !failed
        writer
          .escape_code(:green)
          .text("#{pass_count} passed")
          .escape_code(:reset_fg)
      else
        writer.text("#{pass_count} passed")
      end

      writer.text(", ")

      if skip_count.nonzero? && !failed
        writer
          .escape_code(:yellow)
          .text("#{skip_count} skipped")
          .escape_code(:reset_fg)
      else
        writer.text("#{skip_count} skipped")
      end

      writer.text(", ")

      if failure_count.nonzero?
        writer
          .escape_code(:bold)
          .text("#{failure_count} failed")
          .escape_code(:reset_intensity)
      else
        writer.text("0 failed")
      end

      writer.text(", ")

      if failed
        writer
          .escape_code(:bold)
          .text(numeric_label(error_count, 'total error'))
          .escape_code(:reset_intensity)
          .escape_code(:reset_fg)
      else
        writer.text("0 total errors")
      end

      2.times do
        writer.newline
      end
    end

    def enter_file(path)
      writer
        .text("Running #{path}")
        .newline

      self.previous_byte_offset = writer.byte_offset

      self.file_count += 1
    end

    def exit_file(path, _)
      print_previous_error(false) unless previous_error.nil?

      print_error_details unless error_details.nil?

      if file_error_counter.nonzero?
        errors_by_file[path] = file_error_counter

        self.file_error_counter = 0
      end

      if writer.current?(previous_byte_offset.to_i)
        writer
          .escape_code(:faint)
          .text("(Nothing written)")
          .escape_code(:reset_intensity)
          .newline
          .newline
      end

      self.previous_byte_offset = nil
    end

    def enter_context(title)
      return if title.nil?

      writer
        .indent
        .escape_code(:green)
        .text(title)
        .escape_code(:reset_fg)
        .newline

      writer.increase_indentation
    end

    def exit_context(title, _)
      writer.decrease_indentation unless title.nil?

      print_previous_error(true) unless previous_error.nil?

      print_error_details unless error_details.nil?

      writer.newline if writer.indentation_depth.zero?
    end

    def skip_context(title)
      return if title.nil?

      writer
        .indent
        .escape_code(:yellow)
        .text(title)
        .escape_code(:reset_fg)
        .newline
    end

    def comment(text)
      writer
        .indent
        .text(text)
        .newline
    end

    def finish_test(_, result)
      self.test_count += 1

      if result
        self.pass_count += 1
      else
        self.failure_count += 1
      end

      print_previous_error(true) unless previous_error.nil?

      print_error_details unless error_details.nil?
    end

    def skip_test(_)
      self.skip_count += 1
    end

    def enter_assert_block(_)
      self.assert_block_depth += 1

      return if verbose || assert_block_depth > 1

      writer.start_capture

      2.times do
        writer.increase_indentation
      end
    end

    def exit_assert_block(caller_location, result)
      self.assert_block_depth -= 1

      unless previous_error.nil?
        print_previous_error(false)

        self.previous_error = Fixture::AssertionFailure.build(caller_location)
      end

      return if verbose || assert_block_depth.nonzero?

      captured_text = writer.stop_capture

      unless result
        self.error_details = captured_text
      end

      2.times do
        writer.decrease_indentation
      end
    end

    def error(error)
      self.error_count += 1

      self.file_error_counter += 1

      self.previous_error = error
    end

    def print_previous_error(indent)
      writer.increase_indentation if indent

      print_error(previous_error)

      self.previous_error = nil

      writer.decrease_indentation if indent
    end

    def print_error(error)
      writer.escape_code(:red)

      if reverse_backtraces && error.backtrace.length > 1
        writer
          .indent
          .escape_code(:bold)
          .text("Traceback")
          .escape_code(:reset_intensity)
          .text(" (most recent call last):")
          .newline
      end

      print_error!(error)

      writer
        .escape_code(:reset_fg)
        .sync
    end

    def print_error!(error)
      unless reverse_backtraces
        print_error_message(error)

        print_error_backtrace(error)

        print_error!(error.cause) unless error.cause.nil?
      else
        print_error!(error.cause) unless error.cause.nil?

        print_error_backtrace(error)

        print_error_message(error)
      end
    end

    def print_error_message(error)
      writer
        .indent
        .text("#{error.backtrace[0]}: ")
        .escape_code(:bold)
        .text("#{error.message} (")
        .escape_code(:underline)
        .text(error.class.name)
        .escape_code(:reset_underline)
        .text(")")
        .escape_code(:reset_intensity)
        .newline
    end

    def print_error_backtrace(error)
      omitting = false

      backtrace = error.backtrace[1..-1]

      unless reverse_backtraces
        error_backtrace_iterator = backtrace.each
      else
        frame_count = backtrace.count

        number_width = frame_count.to_s.each_char.count

        error_backtrace_iterator = backtrace.reverse_each.map.with_index do |frame, index|
          ordinal = frame_count - index

          ordinal = ordinal.to_s.rjust(number_width, ' ')

          [frame, ordinal]
        end
      end

      error_backtrace_iterator.each do |frame, ordinal|
        omit = omit_backtrace_pattern.match?(frame)

        next if omit && omitting

        writer
          .text("\t")
          .indent

        if omit
          omitting = true

          if reverse_backtraces
            ordinal.gsub!(/[[:digit:]]/, '?')

            writer.text("#{ordinal}: ")
          end

          writer
            .escape_code(:faint)
            .escape_code(:italic)
            .text('*omitted*')
            .escape_code(:reset_italic)
            .escape_code(:reset_intensity)

        else
          omitting = false

          if reverse_backtraces
            writer.text("#{ordinal}: ")
          end

          writer.text("from #{frame}")
        end

        writer.newline
      end
    end

    def print_error_details
      writer.text(error_details)

      self.error_details = nil
    end

    def numeric_label(number, label, plural_text=nil)
      plural_text ||= 's'

      if number == 1
        "#{number} #{label}"
      else
        "#{number} #{label}#{plural_text}"
      end
    end

    module Defaults
      def self.omit_backtrace_pattern
        pattern = ENV.fetch('TEST_BENCH_OMIT_BACKTRACE_PATTERN') do
          'lib/test_bench'
        end

        Regexp.new(pattern)
      end

      def self.reverse_backtraces
        Environment::Boolean.fetch('TEST_BENCH_REVERSE_BACKTRACES', false)
      end

      def self.verbose
        Environment::Boolean.fetch('TEST_BENCH_VERBOSE', false)
      end
    end
  end
end
