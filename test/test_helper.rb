ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.setup(:default, :development)

require_relative '../lib/exceptional_synchrony.rb'

require 'minitest/autorun' or raise "Already loaded minitest?"
require 'minitest/pride'
require 'webmock'
require 'webmock/minitest'
require 'rr'

ActiveSupport::TestCase.test_order = :sorted

module TestHelper
  @@constant_overrides = []

  def self.included(base)
    base.class_eval do
      before do
        unless @@constant_overrides.nil? || @@constant_overrides.empty?
          raise "Uh-oh! constant_overrides left over: #{@@constant_overrides.inspect}"
        end
        # TODO:this code doesn't seem to be running. But the after code is. Weird. -Colin
      end

      after do
        @@constant_overrides && @@constant_overrides.reverse.each do |parent_module, k, v|
          ExceptionHandling.ensure_completely_safe "constant cleanup #{k.inspect}, #{parent_module}(#{parent_module.class})::#{v.inspect}(#{v.class})" do
            silence_warnings do
              if v == :never_defined
                parent_module.send(:remove_const, k)
              else
                parent_module.const_set(k, v)
              end
            end
          end
        end
        @@constant_overrides = []

        WebMock.reset!
      end
    end
  end

  def set_test_const(const_name, value)
    const_name.is_a?(Symbol) and const_name = const_name.to_s
    const_name.is_a?(String) or raise "Pass the constant name, not its value!"

    final_parent_module = final_const_name = nil
    original_value =
        const_name.split('::').reduce(Object) do |parent_module, nested_const_name|
          parent_module == :never_defined and raise "You need to set each parent constant earlier! #{nested_const_name}"
          final_parent_module = parent_module
          final_const_name    = nested_const_name
          parent_module.const_get(nested_const_name) rescue :never_defined
        end

    @@constant_overrides << [final_parent_module, final_const_name, original_value]

    silence_warnings { final_parent_module.const_set(final_const_name, value) }
  end
end
