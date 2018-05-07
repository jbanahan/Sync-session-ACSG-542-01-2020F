module OpenChain; module Registries; module RegistrySupport
  extend ActiveSupport::Concern

  def check_registration_validity klass, klass_type, required_methods
    non_implemented_methods = required_methods.keep_if {|m| !klass.respond_to?(m) }

    raise "#{klass} must respond to the following methods to be registered as a #{klass_type}: #{non_implemented_methods.map(&:to_s).join(", ")}." if non_implemented_methods.length > 0
    true
  end

  # Calls a method on every registered object
  def evaluate_all_registered method, *args
    values = []
    registered.each {|r| values << r.public_send(method, *args) if r.respond_to?(method) }
    values
  end

  # 
  # This methods will evaluate a method on all the registered objects and ONLY return true if the method
  # returns true for every registered object.  It short-circuits (stops running) and returns false
  # once a single object returns false
  # 
  def evaluate_registered_permission method, *args
    registered.each do |r|
      if r.respond_to?(method)
        val = r.public_send(method, *args)
        return false unless val == true
      end
    end

    return true
  end

end; end; end;