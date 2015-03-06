module OpenChain; module ModelFieldGenerator; module DivisionGenerator
  def make_division_arrays(rank_start,uid_prefix,table_name)
    # The id field is created pretty much solely so the screens can make select boxes using the id as the value parameter
    # and reference the field like prod_imp_id.
    r = [
      [rank_start,"#{uid_prefix}_div_id".to_sym,:division_id,"Division Name",{:history_ignore=>true, user_accessible: false}]
    ]
    n = [rank_start+1,"#{uid_prefix}_div_name".to_sym, :name,"Division Name",{
      :import_lambda => lambda {|obj,data|
        d = Division.where(:name => data).first
        obj.division = d
        unless d.nil?
          return "Division set to #{d.name}"
        else
          return "Division not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|obj| obj.division.nil? ? "" : obj.division.name},
      :qualified_field_name => "(SELECT name FROM divisions WHERE divisions.id = #{table_name}.division_id)",
      :join_statement => "LEFT OUTER JOIN divisions AS #{table_name}_div on #{table_name}_div.id = #{table_name}.division_id",
      :join_alias => "#{table_name}_div",
      :data_type => :string
    }]
    r << n
    r
  end
end; end; end
