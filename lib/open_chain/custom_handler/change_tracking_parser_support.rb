require 'open_chain/mutable_boolean'

# This module provides simple methods that will set standard ActiveRecord attributes
# and custom values into any CoreObject and tracking if that value was changed or not.
#
#
# To utilize this module's set/remove_custom_value methods you must implement
# a cdefs method in your parser class that returns a hash of custom definition
# objects that may be utilized.  What it's looking for is the hash returned
# by any *CustomDefinitionSupport modules implementation of the prep_custom_definitions method.
# (which is a hash composed of a cdef_uid key and CustomDefinition value)
#

module OpenChain; module CustomHandler; module ChangeTrackingParserSupport
  extend ActiveSupport::Concern

  # Sets a given value into the custom value defined by the given cdef_uid.
  #
  # Returns true if the object's custom value was changed.
  #
  # obj - the object to update the custom value on
  # cdef_uid - the cdef_uid for the custom definition (or the actual CustomDefinition object)
  # changed - a MutableBoolen which will be updated to true if the give value
  # differs from the existing custom value.
  # value - the value to set
  #
  # skip_nil_values - no-op if value is nil (regardless of the existing value)
  def set_custom_value obj, cdef_uid, changed, value, skip_nil_values: false
    return false if skip_nil_values && value.nil?

    updated = false
    cdef = cdef_uid.is_a?(CustomDefinition) ? cdef_uid : cdefs[cdef_uid.to_sym]

    cv = obj.find_custom_value(cdef)

    # If the custom value is nil and the passed in value is nil, then don't
    # create the custom value record.
    if !cv.nil? || !value.nil?
      if cv.nil?
        cv = obj.find_and_set_custom_value(cdef, value)
      else
        cv.set_value(cdef, value)
      end

      if cv.changed?
        updated = true
        changed.value = true if changed.present?
      end
    end

    updated
  end

  # Clears the gien custom value value for a given object.  This is mostly just
  # a simple proxy method for passing nil value to the set_custom_value method.
  #
  # Returns true if the object's custom value was changed.
  #
  # obj - the object to update the custom value on
  # cdef_uid - the cdef_uid for the custom definition
  # changed - a MutableBoolen which will be updated to true if the give value
  # differs from the existing custom value.
  def remove_custom_value obj, cdef_uid, changed
    set_custom_value(obj, cdef_uid, changed, nil)
  end

  # Sets the given value into the given attribute field of a standard ActiveRecord object,
  # and sets the given MutableBoolean value to true if the value of the attribute was updated
  # by the given value.
  #
  # Returns true if the value was updated.
  #
  # obj - the ActiveRecord object to update
  # attribute - the object attribute to update
  # changed - A MutableBoolean that will be set to true if the given value updates the object
  # value - the value to set
  def set_value obj, attribute, changed, value
    updated = false
    obj.assign_attributes({attribute.to_sym => value})
    if obj.changes.include?(attribute)
      updated = true
      changed.value = true if changed.present?
    end

    updated
  end

end; end; end