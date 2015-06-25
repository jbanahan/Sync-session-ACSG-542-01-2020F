module OpenChain; module ModelFieldDefinition; module DrawbackClaimFieldDefinition
  def add_drawback_claim_fields
    add_fields CoreModule::DRAWBACK_CLAIM, [
      [1, :dc_name, :name, "Name",{data_type: :string}],
      [2, :dc_exports_start_date, :exports_start_date, "Exports Start", {data_type: :date}],
      [3, :dc_exports_end_date, :exports_end_date, "Exports End", {data_type: :date}],
      [4, :dc_entry_number, :entry_number, "Claim Number", {data_type: :string}],
      [5, :dc_total_pieces_claimed, :total_pieces_claimed, "Total Pieces Claimed", {data_type: :integer}],
      [6, :dc_total_pieces_exported, :total_pieces_exported, "Total Pieces Exported", {data_type: :integer}],
      [7, :dc_planned_claim_amount, :planned_claim_amount, "Planned Claim Amount", {data_type: :currency}],
      [8, :dc_total_export_value, :total_export_value, "Total Export Value", {data_type: :currency}],
      [9, :dc_total_duty, :total_duty, "Total Duty Exported", {data_type: :currency}],
      [10, :dc_hmf_claimed, :hmf_claimed, "HMF Claimed", {data_type: :currency}],
      [11, :dc_mpf_claimed, :mpf_claimed, "MPF Claimed", {data_type: :currency}],
      [12, :dc_duty_check_amount, :duty_check_amount, "Duty Check Amount", {data_type: :currency}],
      [13, :dc_bill_amount, :bill_amount, "Commission", {data_type: :currency}],
      [14, :dc_abi_accepted_date, :abi_accepted_date, "ABI Accepted", {data_type: :date}],
      [15, :dc_sent_to_customs_date, :sent_to_customs_date, "Sent To Customs", {data_type: :date}],
      [16, :dc_billed_date, :billed_date, "Billed", {data_type: :date}],
      [17, :dc_duty_check_received_date, :duty_check_received_date, "Duty Check Received", {data_type: :date}],
      [18, :dc_hmf_mpf_check_number, :hmf_mpf_check_number, "HMF/MPF Check Number", {data_type: :string}],
      [19, :dc_hmf_mpf_check_amount, :hmf_mpf_check_amount, "HMF/MPF Check Amount", {data_type: :currency}],
      [20, :dc_hmf_mpf_check_received_date, :hmf_mpf_check_received_date, "HMF/MPF Check Received", {data_type: :date}],
      [21, :dc_duty_claimed, :duty_claimed, "Duty Claimed", {data_type: :currency}],
      [22, :dc_rule_state,:rule_state,"Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state },
        :qualified_field_name=> "(select state
          from business_validation_results bvr
          where bvr.validatable_type = 'Entry' and bvr.validatable_id = drawback_claims.id
          order by (
          case bvr.state
              when 'Fail' then 0
              when 'Review' then 1
              when 'Pass' then 2
              when 'Skipped' then 3
              else 4
          end
          )
          limit 1)",
        :can_view_lambda=>lambda {|u| u.company.master?}
      }]
    ]
    add_fields CoreModule::DRAWBACK_CLAIM, make_importer_arrays(100, "dc", "drawback_claims")
  end
end; end; end