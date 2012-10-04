#List of CoreModules in a parent -> child -> grandchild setup
class ModuleChain

  @list

  #add a CoreModule to the end of the list
  def add(cm) 
    @list = [] if @list.nil?
    @list << cm
  end

  def add_array(mods)
    mods.each {|m| add m}
  end

  def to_a
    @list.nil? ? [] : @list.clone
  end

  def child_modules(cm)
    idx = @list.index cm
    return [] if idx.nil? || idx==(@list.length-1)
    @list.slice idx+1, (@list.length-(idx+1))
  end
  def first
    @list.first
  end
  
  #returns true if the given module is the first one in the chain
  def top? cm
    @list.first == cm
  end
  #returns the immediate parent module in the chain (or nil if you're at the top of the chain)
  def parent cm
    idx = @list.index cm
    (idx==0 || idx.nil?) ? nil : @list[idx-1]
  end 
  #returns the immediate child module in the chian (or nil if you're at the bottom of the chain)
  def child cm
    idx = @list.index cm
    (idx+1>=@list.length || idx.nil?) ? nil : @list[idx+1]
  end
end
