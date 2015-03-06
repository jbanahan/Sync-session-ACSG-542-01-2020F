module OpenChain; module ModelFieldGenerator; module SyncRecordGenerator
  def make_sync_record_arrays sequence_start, prefix, table, class_name
    [
      [sequence_start,"#{prefix}_sync_record_count".to_sym, :sync_record_count, "Sync Record Count", {:data_type=>:integer,
        :import_lambda=> lambda {|o,d| "Number of Sync Records ignored. (read only)"},
        :export_lambda=> lambda {|obj| obj.sync_records.size},
        :qualified_field_name=> "(SELECT COUNT(*) FROM sync_records num_sr WHERE num_sr.syncable_id = #{table}.id AND num_sr.syncable_type = '#{class_name}')",
        :history_ignore=>true
      }],
      [sequence_start+1,"#{prefix}_sync_problems".to_sym, :sync_problems, "Sync Record Problems?", {:data_type=>:boolean,
        :import_lambda=> lambda {|o,d| "Sync Record Problems ignored. (read only)"},
        :export_lambda=> lambda {|obj| obj.sync_records.problems.size > 0 ? true : false},
        :qualified_field_name=> "(SELECT CASE COUNT(*) WHEN 0 THEN false ELSE true END FROM sync_records sr_fail WHERE sr_fail.syncable_id = #{table}.id AND sr_fail.syncable_type = '#{class_name}' AND (#{SyncRecord.problems_clause('sr_fail.')}))",
        :history_ignore=>true
      }],
      [sequence_start+2,"#{prefix}_sync_last_sent".to_sym,:sync_last_sent,"Sync Record Last Sent",{
        data_type: :datetime,
        import_lambda: lambda {|o,d| "Sync Record Last Sent ignored (read only)"},
        export_lambda: lambda {|o| o.sync_records.collect {|r| r.sent_at}.compact.sort.last},
        qualified_field_name: "(SELECT max(sent_at) FROM sync_records where sync_records.syncable_id = #{table}.id AND sync_records.syncable_type = '#{class_name}')",
        history_ignore: true
        }
      ],
      [sequence_start+3,"#{prefix}_sync_last_confirmed".to_sym,:sync_last_confirmed,"Sync Record Last Confirmed",{
        data_type: :datetime,
        import_lambda: lambda {|o,d| "Sync Record Last Confirmed ignored (read only)"},
        export_lambda: lambda {|o| o.sync_records.collect {|r| r.confirmed_at}.compact.sort.last},
        qualified_field_name: "(SELECT max(confirmed_at) FROM sync_records where sync_records.syncable_id = #{table}.id AND sync_records.syncable_type = '#{class_name}')",
        history_ignore: true
        }
      ]
    ]
  end
end; end; end
