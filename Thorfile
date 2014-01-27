require 'thor'

$LOAD_PATH.unshift('lib')

class Dev < Thor
  package_name 'dev'

  desc 'test' , 'Run the entire test suite or a single file.'
  method_options :file => :string, :n => :string
  def test

    ENV['RACK_ENV'] = 'test'

    require 'bundler'
    Bundler.require(:default, :test)

    (old, $VERBOSE) = [$VERBOSE, nil]
    Bundler.require(:default)
    $VERBOSE = old

    require 'webmock'
    require './test/test_helper.rb'

    # Minitest is very bad and piggy backs on the Global arguments just like everyone else.
    # Let's stop it from trying to parse Thor's arguments.
    clear_args

    add_args('-n', options[:n]) if options[:n]

    # If we have a single file run it, otherwise run them all.
    if single_file = options[:file]
      require single_file
    else
      Dir.glob('./test/**/*_test.rb') { |f| require f }
    end
  end

private
  def clear_args
    ARGV.shift(ARGV.length)
  end

  def add_args(*args)
    args.each { |arg| ARGV << arg }
  end
end

