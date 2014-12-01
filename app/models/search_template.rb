class SearchTemplate < ActiveRecord::Base
  validates :name, uniqueness: true, presence: true
  validates :search_json, presence: true

  # create and return a new SearchTemplate based on the search setup
  def self.create_from_search_setup! search_setup
    st = self.new(
      name:search_setup.name,
      module_type:search_setup.module_type)
    st.search_json = make_json_from_search_setup(search_setup)
    st.save!
    st
  end

  # add this template as a SearchSetup in the given user's account
  def add_to_user! u
    raise "search_json not set" if self.search_json.blank?
    h = JSON.parse self.search_json
    ss = u.search_setups.build(
      name:h['name'],
      module_type:h['module_type'],
      include_links:h['include_links'],
      no_time:h['no_time']
    )
    if h['search_columns']
      h['search_columns'].each do |sc|
        ss.search_columns.build(
          model_field_uid:sc['model_field_uid'],
          rank:sc['rank']
        )
      end
    end
    if h['search_criterions']
      h['search_criterions'].each do |sc|
        ss.search_criterions.build(
          model_field_uid:sc['model_field_uid'],
          operator:sc['operator'],
          value:sc['value']
        )
      end
    end
    if h['sort_criterions']
      h['sort_criterions'].each do |sc|
        ss.sort_criterions.build(
          model_field_uid:sc['model_field_uid'],
          rank:sc['rank'],
          descending:sc['descending']
        )
      end
    end
    ss.save!
    ss
  end

  private
  def self.make_json_from_search_setup ss
    h = {name:ss.name,
      module_type:ss.module_type,
      include_links:ss.include_links,
      no_time:ss.no_time
    }
    h[:search_columns] = ss.search_columns.collect {|sc| {model_field_uid:sc.model_field_uid,rank:sc.rank}}
    h[:search_criterions] = ss.search_criterions.collect {|sc| {model_field_uid:sc.model_field_uid,operator:sc.operator,value:sc.value}}
    h[:sort_criterions] = ss.sort_criterions.collect {|sc| {model_field_uid:sc.model_field_uid,rank:sc.rank,descending:sc.descending}}
    h.to_json
  end
end
