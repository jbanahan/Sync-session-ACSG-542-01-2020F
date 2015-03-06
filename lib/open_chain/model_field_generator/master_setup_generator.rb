module OpenChain; module ModelFieldGenerator; module MasterSetupGenerator
  def make_master_setup_array rank_start, uid_prefix
    r = []
    r << [rank_start,"#{uid_prefix}_system_code".to_sym,:system_code,"Master System Code", {
      :import_lambda => lambda {|detail,data| return "Master System Code cannot by set by import, ignored."},
      :export_lambda => lambda {|detail| return MasterSetup.get.system_code},
      :qualified_field_name => "(SELECT system_code FROM master_setups LIMIT 1)",
      :data_type=>:string,
      :history_ignore=>true
    }]
  end
end; end; end
