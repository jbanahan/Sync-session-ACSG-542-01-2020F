module ConfigMigrations; module Www; class TariffFileMonitorSow1630

  def up
    add_tariff_file_upload_definitions
  end

  def down
    delete_tariff_file_upload_definitions
  end

  def add_tariff_file_upload_definitions
    # Argentina
    tar_def = TariffFileUploadDefinition.create!(country_code:"AR", filename_regex:"AR_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Australia
    tar_def = TariffFileUploadDefinition.create!(country_code:"AU", filename_regex:"AU_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Brazil
    tar_def = TariffFileUploadDefinition.create!(country_code:"BR", filename_regex:"BR_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Canada
    tar_def = TariffFileUploadDefinition.create!(country_code:"CA", filename_regex:"CA_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"ann")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"dasvfitracknet")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"ll")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Chile
    tar_def = TariffFileUploadDefinition.create!(country_code:"CL", filename_regex:"CL_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # China (10-digit HTS)
    tar_def = TariffFileUploadDefinition.create!(country_code:"CN", filename_regex:"CN_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # China (13-digit HTS)
    tar_def = TariffFileUploadDefinition.create!(country_code:"C9", filename_regex:"C9_SIMPLE_.+\.ZIP", country_iso_alias:"CN")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")

    # Colombia
    tar_def = TariffFileUploadDefinition.create!(country_code:"CO", filename_regex:"CO_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # European Union
    tar_def = TariffFileUploadDefinition.create!(country_code:"EU", filename_regex:"EU_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi", country_iso_alias:"IE")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo", country_iso_alias:"IT")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour", country_iso_alias:"NL")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net", country_iso_alias:"IT")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo", country_iso_alias:"IT")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test", country_iso_alias:"IT")

    # Hong Kong
    tar_def = TariffFileUploadDefinition.create!(country_code:"HK", filename_regex:"HK_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # India
    tar_def = TariffFileUploadDefinition.create!(country_code:"IN", filename_regex:"IN_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Indonesia
    tar_def = TariffFileUploadDefinition.create!(country_code:"ID", filename_regex:"ID_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Israel
    tar_def = TariffFileUploadDefinition.create!(country_code:"IL", filename_regex:"IL_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Japan
    tar_def = TariffFileUploadDefinition.create!(country_code:"JP", filename_regex:"JP_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Malaysia
    tar_def = TariffFileUploadDefinition.create!(country_code:"MY", filename_regex:"MY_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Macao
    tar_def = TariffFileUploadDefinition.create!(country_code:"MO", filename_regex:"MO_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Mexico
    tar_def = TariffFileUploadDefinition.create!(country_code:"MX", filename_regex:"MX_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # New Zealand
    tar_def = TariffFileUploadDefinition.create!(country_code:"NZ", filename_regex:"NZ_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Norway
    tar_def = TariffFileUploadDefinition.create!(country_code:"NO", filename_regex:"NO_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Panama
    tar_def = TariffFileUploadDefinition.create!(country_code:"PA", filename_regex:"PA_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Pakistan
    tar_def = TariffFileUploadDefinition.create!(country_code:"PK", filename_regex:"PK_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Philippines
    tar_def = TariffFileUploadDefinition.create!(country_code:"PH", filename_regex:"PH_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Russia
    tar_def = TariffFileUploadDefinition.create!(country_code:"RU", filename_regex:"RU_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Singapore
    tar_def = TariffFileUploadDefinition.create!(country_code:"SG", filename_regex:"SG_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # South Korea
    tar_def = TariffFileUploadDefinition.create!(country_code:"KR", filename_regex:"KR_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Taiwan
    tar_def = TariffFileUploadDefinition.create!(country_code:"TW", filename_regex:"TW_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Thailand
    tar_def = TariffFileUploadDefinition.create!(country_code:"TH", filename_regex:"TH_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Turkey
    tar_def = TariffFileUploadDefinition.create!(country_code:"TR", filename_regex:"TR_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # UAE
    tar_def = TariffFileUploadDefinition.create!(country_code:"AE", filename_regex:"AE_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # USA
    tar_def = TariffFileUploadDefinition.create!(country_code:"US", filename_regex:"US_WITH_ABI_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"ann")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"dasvfitracknet")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"ll")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"rhee")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"underarmour")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Uruguay
    tar_def = TariffFileUploadDefinition.create!(country_code:"UY", filename_regex:"UY_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Venezuela
    tar_def = TariffFileUploadDefinition.create!(country_code:"VE", filename_regex:"VE_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"pepsi")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")

    # Vietnam
    tar_def = TariffFileUploadDefinition.create!(country_code:"VN", filename_regex:"VN_SIMPLE_.+\.ZIP")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"polo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"www-vfitrack-net")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"bdemo")
    TariffFileUploadInstance.create!(tariff_file_upload_definition:tar_def, vfi_track_system_code:"test")
  end

  def delete_tariff_file_upload_definitions
    TariffFileUploadDefinition.destroy_all
  end

end; end; end