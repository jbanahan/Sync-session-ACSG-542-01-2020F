#List of CoreModules in a parent -> child -> grandchild setup
class ModuleChain

  class SiblingModules

    def initialize *modules
      @mods = []
      @mods.push *modules
    end

    def modules
      @mods.clone
    end

    def include? cm
      @mods.include? cm
    end
  end

  #add a CoreModule to the end of the list
  def add(cm) 
    @list = [] if @list.nil?
    raise "SiblingModules cannot be used at the top of a ModuleChain" if @list.size == 0 && cm.is_a?(SiblingModules)
    raise "You cannot add modules to a chain that already contains a SiblingModule. SiblingModules must be at the bottom of the chain." if has_sibling_module?
    @list << cm
  end

  def add_array(mods)
    mods.each {|m| add m}
  end

  def to_a
    @list.nil? ? [] : flatten_module_chain(@list)
  end

  def child_modules(cm)
    found_index = index(cm)
    found_index.nil? ? [] : flatten_module_chain(@list[(found_index + 1)..-1])
  end

  def first
    @list.first
  end
  
  #returns true if the given module is the first one in the chain
  def top? cm
    index(cm) == 0
  end

  #returns the immediate parent module in the chain (or nil if you're at the top of the chain)
  def parent cm
    idx = index(cm)

    # Because we're enforcing that sibling modules MUST be at the lowest level of the module chain, we're safe
    # always using the index - 1 for the parent, since the parent will never be a sibling module.
    (idx == 0 || idx.nil?) ? nil : @list[idx - 1]
  end 

  #returns the immediate child module in the chain (or nil if you're at the bottom of the chain)
  def child cm
    idx = index(cm)
    return nil if (idx.nil? || idx >= @list.length)

    mod = @list[idx + 1]
    mod.is_a?(SiblingModules) ? mod.modules : (mod.nil? ? nil : [mod])
  end

  # returns hash of all model fields for all core modules in the chain keyed by uid
  def model_fields user=nil
    h = {}
    self.to_a.each do |cm|
      h.merge! cm.model_fields(user)
    end
    h
  end

  private 
    def index cm
      found_index = nil
      Array.wrap(@list).each_with_index do |child, x|
        if child.is_a?(SiblingModules)
          found_index = x if child.include? cm
        else
          found_index = x if child == cm
        end

        break unless found_index.nil?
      end

      found_index
    end

    def flatten_module_chain list
      list.map do |cm|
        if cm.is_a?(SiblingModules)
          cm.modules
        else
          cm
        end
      end.flatten
    end

    def has_sibling_module?
      !@list.find {|cm| cm.is_a?(SiblingModules) }.nil?
    end

end
