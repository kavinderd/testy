require 'rubygems'
require 'orderedhash'
require 'yaml'

module Testy
  class Test
    class BadResult < StandardError
    end

    class OrderedHash < ::OrderedHash
      def with_string_keys
        oh = self.class.new
        each_pair{|key, val| oh[key.to_s] = val}
        oh
      end
    end

    class Result
      attr_accessor :expect
      attr_accessor :actual

      def initialize
        @expect = OrderedHash.new
        @actual = OrderedHash.new
      end

      def check(name, *args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        value = args.size==0 ? (options[:expect]||options['expect']) : args.shift
        expect[name.to_s] = value
        value = args.size==0 ? (options[:actual]||options['actual']) : args.shift
        actual[name.to_s] = value
      end

      def ok?
        expect == actual
      end
    end

    attr_accessor :name
    attr_accessor :tests
    attr_accessor :block

    def initialize(*args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      @name = args.first || options[:name] || options['name']
      @tests = OrderedHash.new
      @block = block
    end

    def test(name, &block)
      @tests[name.to_s] = block
    end

    def run port = STDOUT
      instance_eval(&@block) if @block
      report = OrderedHash.new
      status = 0
      tests.each do |name, block|
        result = Result.new
        report[name] =
          begin
            block.call(result)
            raise BadResult, name unless result.ok?
            {'success' => result.actual}
          rescue Object => e
            status += 1
            failure = OrderedHash.new
            unless e.is_a?(BadResult)
              error = OrderedHash.new
              error['class'] = e.class.name
              error['message'] = e.message.to_s
              error['bactrace'] = e.backtrace||[]
              failure['error'] = error
            end
            failure['expect'] = result.expect
            failure['actual'] = result.actual
            {'failure' => failure}
          end
      end
      port << {name => report}.to_yaml
      exit(status)
    end
  end
    
  def Testy.testing(*args, &block)
    Test.new(*args, &block).run
  end
end
