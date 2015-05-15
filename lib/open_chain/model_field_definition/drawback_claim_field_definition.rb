module OpenChain; module ModelFieldDefinition
  class DrawbackClaimFieldDefiner < ModelFieldDefiner
    def prefix; 'dc'; end
    def core_module; CoreModule::DRAWBACK_CLAIM; end

    def fields
       [field(:name),
       field(:exports_start_date, {description: "Exports Start", data_type: :date}),
       field(:exports_end_date, {description: "Exports End", data_type: :date}),
       field(:entry_number, description: "Claim Number"),
       field(:total_pieces_claimed, {data_type: :integer}),
       field(:total_pieces_exported, {data_type: :integer}),
       field(:planned_claim_amount, {data_type: :currency}),
       field(:total_export_value, {data_type: :currency}),
       field(:total_duty, {description: "Total Duty Exported", data_type: :currency}),
       field(:hmf_claimed, {description: "HMF Claimed", data_type: :currency}),
       field(:mpf_claimed, {description: "MPF Claimed", data_type: :currency}),
       field(:duty_check_amount, {description:"Duty Check Amount", data_type: :currency}),
       field(:bill_amount, {description:"Commission", data_type: :currency}),
       field(:abi_accepted_date, {description:"ABI Accepted", data_type: :date}),
       field(:sent_to_customs_date, {description:"Sent To Customs", data_type: :date}),
       field(:billed_date, {description:"Billed", data_type: :date}),
       field(:duty_check_received_date, {description:"Duty Check Received", data_type: :date}),
       field(:hmf_mpf_check_number, {description:"HMF/MPF Check Number", data_type: :string}),
       field(:hmf_mpf_check_amount, {description:"HMF/MPF Check Amount", data_type: :currency}),
       field(:hmf_mpf_check_received_date, {description:"HMF/MPF Check Received", data_type: :date}),
       field(:duty_claimed, {data_type: :currency})]
      .concat make_importer_arrays(100, prefix, core_module.table_name)
    end

  end

end; end