# groups logic for User class
module OpenChain; module UserSupport; module Groups
  def in_group? group
    return false if group.nil?

    cache = group_cache(true)
    to_find = group.respond_to?(:system_code) ? group.system_code : group
    cache.include? to_find.to_s
  end

  def in_any_group? groups
    groups.each do |g|
      return true if self.in_group? g
    end
    return false
  end

  def user_group_codes
    group_cache(true).to_a
  end

  def group_cache(ensure_created)
    if @group_cache.nil? && ensure_created
      @group_cache = SortedSet.new self.groups.map(&:system_code)
    end

    @group_cache
  end

  def add_to_group_cache group
    group_cache(true) << group.system_code
    nil
  end

  def remove_from_group_cache group
    group_cache(false).try(:delete, group.system_code)
    nil
  end
end; end; end
