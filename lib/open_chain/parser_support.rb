module OpenChain; module ParserSupport

  class Updater
    def initialize
      @changed = false
    end

    def changed?
      @changed
    end

    def set_changed
      @changed = true
    end

    def reset
      @changed = false
    end

    def set entity, value, attrib: nil,  cdef: nil
      raise "Method must be called with either an attribute or a custom definition" unless attrib || cdef
      if attrib
        current_value = entity.public_send attrib
        entity.public_send "#{attrib.to_s}=".to_sym, value
        set_changed if entity.changed?
      else
        entity.find_and_set_custom_value cdef, value
        set_changed if entity.get_custom_value(cdef).changed?
      end

      nil
    end
  end

end; end
