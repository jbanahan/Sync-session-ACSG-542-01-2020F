module OpenChain; module CustomHandler; module GroupSupport
  # returns a hash with the group system code as the key and the
  # group object as the value for all group_codes that live in the group_code_name_hash
  def prep_group_objects group_codes, group_code_name_hash
    r = HashWithIndifferentAccess.new
    group_codes.each do |code|
      name = group_code_name_hash[code]
      next if name.blank?
      r[code] = Group.use_system_group code, name
    end
    r
  end
end; end; end
