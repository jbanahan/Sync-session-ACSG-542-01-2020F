module OpenChain; module ModelFieldGenerator; module LastChangedByGenerator
  def make_last_changed_by rank, uid_prefix, base_class
    table_name = base_class.table_name
    [
      [rank,"#{uid_prefix}_last_changed_by".to_sym,:username,"Last Changed By", {
        :import_lambda => lambda {|a,b| return "Last Changed By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          obj.last_updated_by.blank? ? "" : obj.last_updated_by.username
        },
        :qualified_field_name => "(SELECT username FROM users where users.id = #{table_name}.last_updated_by_id)",
        :data_type=>:string,
        :history_ignore => true
      }],
      [rank + 1,"#{uid_prefix}_last_changed_by_full_name".to_sym,:username,"Last Changed By Full Name", {
        :import_lambda => lambda {|a,b| return "Last Changed By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          # purposefully not using the fullname user method, since it falls back to returning username if names are blank, which we don't want here
          obj.last_updated_by.blank? ? "" : ("#{obj.last_updated_by.first_name} #{obj.last_updated_by.last_name}")
        },
        :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = #{table_name}.last_updated_by_id)",
        :data_type=>:string,
        :history_ignore => true
      }]
    ]
  end
end; end; end
