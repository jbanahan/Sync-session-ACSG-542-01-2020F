module OpenChain; module ModelFieldDefinition; module SecurityFilingLineFieldDefinition
  def add_security_filing_line_fields
    add_fields CoreModule::SECURITY_FILING_LINE, [
      [2,:sfln_line_number,:line_number,"Line Number",{:data_type=>:integer}],
      [4,:sfln_hts_code,:hts_code,"HTS Code",{:data_type=>:string}],
      [5,:sfln_part_number,:part_number,"Part Number",{:data_type=>:string}],
      [6,:sfln_po_number,:po_number,"PO Number",{:data_type=>:string}],
      [7,:sfln_commercial_invoice_number,:commercial_invoice_number,"Commercial Invoice Number",{:data_type=>:string}],
      [8,:sfln_mid,:mid,"MID",{:data_type=>:string}],
      [9,:sfln_country_of_origin_code,:country_of_origin_code,"Country of Origin Code",{:data_type=>:string}],
      [10,:sfln_manufacturer_name,:manufacturer_name,"Manfacturer Name",{:data_type=>:string}]
    ]
  end
end; end; end
