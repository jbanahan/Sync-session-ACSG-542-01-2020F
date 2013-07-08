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
    def deep_copy(new_name, copy_schedules = false) 
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


      if copy_schedules && self.respond_to?(:search_schedules)
        self.search_schedules.each do |sched|
          ss.search_schedules.build(atts.call(sched))
        end
      end

      ss.save!
      ss
    end

    # Makes a deep copy of the search and assigns it to the given user
    def give_to other_user, copy_schedules = false
      # Remove any previous iterations of "(From Username)" from the search to avoid having (From X) (From Y) (From Z)
      # tacked onto the search name.
      copy_name = self.name
      match_start = -1

      # Essentially we're just iteratively removing the (From X) value from the name until we don't find it any longer
      # Match anything ending with whitespace + "(From" +  non-) chars + ")" + any number of spaces
      # This regex fails to match if a persons name has parenthesis in it..which shouldn't happen.
      # Even then, the user can easily remove any Froms left in the name manually..no big deal
      while !(match_start = (copy_name =~ /\s*\(From [^)]+?\)\s*\z/)).nil? && match_start >= 0
        copy_name = copy_name[0, match_start]
      end

      ss = deep_copy copy_name +" (From #{self.user.full_name})", copy_schedules
      ss.user = other_user
      ss.save
    end
  end
end
