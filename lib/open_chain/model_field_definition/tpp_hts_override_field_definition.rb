module OpenChain; module ModelFieldDefinition; module TppHtsOverrideFieldDefinition
  def add_tpp_hts_override_fields
    add_fields CoreModule::TPP_HTS_OVERRIDE, [
      [1, :tpphtso_hts_code, :hts_code, 'HTS Code', {data_type: :string}],
      [2, :tpphtso_rate, :rate, 'Override Rate', {data_type: :decimal}],
      [3, :tpphtso_note, :note, 'Note', {data_type: :text}],
      [4, :tpphtso_trade_preference_program_id, :trade_preference_program_id, 'Preference Program DB ID', {
        data_type: :integer,
        import_lambda: lambda {|obj,data|
          return "Cannot clear Preference Program for an HTS Override." if data.blank? && !obj.trade_preference_program_id.blank?
          return "Preference Program not changed, update ignored." if obj.trade_preference_program_id.to_s == data.to_s
          if obj.trade_preference_program_id.blank?
            obj.trade_preference_program_id = data
          else
            return "Cannot change Preference Program for an HTS Override, update ignored."
          end
        }
      }],
      [5, :tpphtso_active, :active, 'Is Active', {
        data_type: :boolean,
        read_only: true,
        export_lambda: lambda {|obj|
          obj.active?
        },
        qualified_field_name: "IF(#{TppHtsOverride.active_where_clause},true,false)"
      }],
      [6, :tpphtso_start_date, :start_date, 'Start Date', {data_type: :date}],
      [7, :tpphtso_end_date, :end_date, 'End Date', {data_type: :date}]
    ]
  end
end; end; end
