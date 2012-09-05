module OpenChain
  module SearchBase
    #get all column fields as ModelFields that are not already included as search columns
    def unused_column_fields user
      used = self.search_columns.collect {|sc| sc.model_field_uid}
      ModelField.sort_by_label column_fields_available(user).collect {|mf| mf unless used.include? mf.uid.to_s}.compact
    end

    def sorted_columns
      self.search_columns.order("rank ASC")
    end
  end
end
