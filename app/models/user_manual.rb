class UserManual < ActiveRecord::Base
  attr_accessible :groups, :name, :page_url_regex, :wistia_code, :category
  validates :name, presence: true

  has_one :attachment, :as => :attachable, :dependent=>:destroy

  def self.for_user_and_page user, url
    UserManual.all.find_all do |um|
      user_group_system_codes = user.groups.pluck(:system_code)
      regex = um.page_url_regex
      regex = /./ if regex.blank?
      url.match(regex) do |match|
        um.can_view?(user, user_group_system_codes)
      end
    end
  end

  # sort the given collection into an hash keyed by category 
  # with each value being an array of user manuals sorted by name
  def self.to_category_hash coll
    cat_hash = Hash.new {|h,k| h[k] = []}
    coll.each do |um|
      n = um.category.blank? ? '' : um.category
      cat_hash[n] << um
    end
    cat_hash.each {|k,v| v.sort_by! {|e| [e.name,e.id]}}
    cat_hash
  end
  
  # user_group_system_codes is an optimization for when you're calling this
  # in a loop over multiple UserManuals. It can be ignored, and the groups
  # will be loaded from the user object if it is not passed
  def can_view? user, user_group_system_codes = nil
    return true if self.groups.blank?

    ugs = user_group_system_codes || user.groups.pluck(:system_code)
    user_groups = ugs.collect {|sc| sc.downcase}

    # return true if user in ANY of the groups listed for the manual
    group_array = self.groups.lines.collect {|ln| ln.downcase.strip}
    return (group_array & user_groups).length > 0
  end
end
