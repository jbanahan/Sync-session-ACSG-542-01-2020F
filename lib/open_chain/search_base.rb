module OpenChain
  module SearchBase
    #get all column fields as ModelFields that are not already included as search columns
    def unused_column_fields user
      used = self.search_columns.collect {|sc| sc.model_field_uid}
      ModelField.sort_by_label column_fields_available(user).collect {|mf| mf unless used.include? mf.uid.to_s}.compact
    end

    def sorted_columns
      self.persisted? ? self.search_columns.order("rank ASC") : []
    end
    # Returns a copy of self with matching columns, search & sort criterions 
    # all built.
    #
    # If a true parameter is provided, everything in the tree will be saved to the database.
    def deep_copy(new_name) 
      atts = lambda {|obj| obj.attributes.delete_if {|k,v| ["id","created_at","updated_at"].include? k}}
      ss = self.class.new(atts.call(self))
      ss.name = new_name
      self.search_criterions.each do |sc|
        new_sc = ss.search_criterions.build(atts.call(sc))
      end
      self.search_columns.each do |sc|
        new_sc = ss.search_columns.build(atts.call(sc))
      end
      if self.respond_to? :sort_criterions
        self.sort_criterions.each do |sc|
          new_sc = ss.sort_criterions.build(atts.call(sc))
        end
      end
      ss.save!
      ss
    end
    # Makes a deep copy of the search and assigns it to the given user
    def give_to other_user
      ss = deep_copy self.name+" (From #{self.user.full_name})"
      ss.user = other_user
      ss.save
    end
  end
end
