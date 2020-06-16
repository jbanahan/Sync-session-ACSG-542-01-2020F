module OpenChain; module ModelFieldDefinition; module PgaSummaryFieldDefinition
  def add_pga_summary_fields
    add_fields CoreModule::PGA_SUMMARY, [
      [1, :pgasum_sequence_number, :sequence_number, "Sequence Number", {data_type: :integer}],
      [2, :pgasum_agency_code, :agency_code, "Agency Code", {data_type: :string}],
      [3, :pgasum_agency_processing_code, :agency_processing_code, "Agency Processing Code", {data_type: :string}],
      [4, :pgasum_commercial_description, :commercial_description, "Commercial Description", {data_type: :string}],
      [5, :pgasum_disclaimer_type_code, :disclaimer_type_code, "Disclaimer Type Code", {data_type: :string}],
      [6, :pgasum_program_code, :program_code, "Program Code", {data_type: :string}],
      [7, :pgasum_tariff_regulation_code, :tariff_regulation_code, "Tariff Regulation Code", {data_type: :string}]
    ]
  end
end; end; end