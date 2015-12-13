# groups logic for User class
module OpenChain; module UserSupport; module Groups
  def in_group? group
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
end; end; end
