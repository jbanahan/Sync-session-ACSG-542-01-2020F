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

  def child_modules(cm)
    idx = @list.index cm
    return [] if idx.nil? || idx==(@list.length-1)
    @list.slice idx+1, (@list.length-(idx+1))
  end
  def first
    @list.first
  end
end
