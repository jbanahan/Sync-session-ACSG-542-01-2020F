describe OpenChain::CustomHandler::Vandegrift::KewillProductGeneratorSupport do
  subject do
    Class.new do
      include OpenChain::CustomHandler::Vandegrift::KewillProductGeneratorSupport
    end.new
  end

  describe 'write_tariff_data_to_xml' do
    let(:doc) { REXML::Document.new('<root></root>').root }
    let(:c) { described_class }
    let(:product_data) do
      p = c::ProductData.new
      p.customer_number = 'TEST'
      p.part_number = 'PART'
      p.effective_date = Date.new(2020, 4, 14)
      p.expiration_date = Date.new(2020, 5, 1)
      p.description = 'DESCRIPTION'
      p.country_of_origin = 'CO'
      p.mid = 'MID'
      p.product_line = 'LINE'
      p.tsca_certification = 'A'
      p.tariff_data = []
      p.penalty_data = []

      p.penalty_data << c::PenaltyData.new('CVD', 'C-123')

      t = c::TariffData.new('1234567890')
      t.spi = 'SP'
      t.spi2 = 'X'
      t.description = 'TARIFF DESC'
      t.description_date = Date.new(2020, 4, 15)
      t.fda_flag = true
      t.dot_flag = false
      t.fws_flag = true
      t.lacey_flag = false
      t.fcc_flag = true
      t.fda_data = []
      t.lacey_data = []
      t.dot_data = []
      t.fish_wildlife_data = []

      p.tariff_data << t

      d = c::DotData.new
      d.nhtsa_program = 'DOT'
      d.box_number = '2A'
      t.dot_data << d

      f = c::FdaData.new
      f.product_code = 'PROD'
      f.uom = 'UOM'
      f.country_production = 'CO'
      f.mid = 'MID'
      f.shipper_id = 'SHIPPER'
      f.description = 'DESC'
      f.establishment_number = 'EST'
      f.container_dimension_1 = 'DIM1'
      f.container_dimension_2 = 'DIM2'
      f.container_dimension_3 = 'DIM3'
      f.contact_name = 'NAME'
      f.contact_phone = 'PHONE'
      f.cargo_storage_status = 'S'
      f.affirmations_of_compliance = [c::FdaAffirmationOfComplianceData.new('AFF', 'QUAL'),
                                      c::FdaAffirmationOfComplianceData.new('AF2', nil)]
      t.fda_data = [f]

      l = c::LaceyData.new
      l.preparer_name = 'NAME'
      l.preparer_email = 'EMAIL'
      l.preparer_phone = 'PHONE'
      l.components = []
      t.lacey_data = [l]

      lc = c::LaceyComponentData.new
      lc.component_of_article = 'COMP'
      lc.country_of_harvest = 'CN'
      lc.quantity = 10
      lc.quantity_uom = 'M3'
      lc.percent_recycled = BigDecimal('50.5')
      lc.common_name_general = 'GEN NAME'
      lc.scientific_names = [c::ScientificName.new('GEN', 'SPEC'), c::ScientificName.new('GEN2', 'SPEC2')]
      l.components << lc

      fw = c::FishWildlifeData.new
      fw.common_name_general = 'GEN'
      fw.country_where_born = 'CO'
      fw.foreign_value = BigDecimal('20.25')
      fw.description_code = 'CD'
      fw.source_description = 'THE WILD'
      fw.source_code = 'W'
      fw.scientific_name = c::ScientificName.new('GENUS', 'SPECIES')
      t.fish_wildlife_data = [fw]

      epa = c::EpaData.new
      epa.epa_code = 'EP5'
      epa.epa_program_code = 'TS1'
      epa.positive_certification = true
      t.epa_data = [epa]

      p
    end

    it 'writes all data to xml' do
      subject.write_tariff_data_to_xml doc, product_data

      expect(doc.text('part/id/partNo')).to eq 'PART'
      expect(doc.text('part/id/custNo')).to eq 'TEST'
      expect(doc.text('part/id/dateEffective')).to eq '20200414'
      expect(doc.text('part/dateExpiration')).to eq '20200501'
      expect(doc.text('part/styleNo')).to eq 'PART'
      expect(doc.text('part/countryOrigin')).to eq 'CO'
      expect(doc.text('part/manufacturerId')).to eq 'MID'
      expect(doc.text('part/descr')).to eq 'DESCRIPTION'
      expect(doc.text('part/productLine')).to eq 'LINE'
      expect(doc.text('part/tscaCert')).to eq 'A'

      expect(doc.text('part/CatTariffClassList/CatTariffClass/partNo')).to eq 'PART'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/custNo')).to eq 'TEST'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/dateEffective')).to eq '20200414'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/seqNo')).to eq '1'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/tariffNo')).to eq '1234567890'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/spiPrimary')).to eq 'SP'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/spiSecondary')).to eq 'X'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/dotOgaFlag')).to eq 'N'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/fdaOgaFlag')).to eq 'Y'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/fwsOgaFlag')).to eq 'Y'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/lcyPgaFlag')).to eq 'N'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/fccOgaFlag')).to eq 'Y'

      fda = REXML::XPath.first doc, 'part/CatTariffClassList/CatTariffClass/CatFdaEsList/CatFdaEs'
      expect(fda).not_to be_nil
      expect(fda.text('partNo')).to eq 'PART'
      expect(fda.text('styleNo')).to eq 'PART'
      expect(fda.text('custNo')).to eq 'TEST'
      expect(fda.text('dateEffective')).to eq '20200414'

      expect(fda.text('seqNo')).to eq '1'
      expect(fda.text('fdaSeqNo')).to eq '1'
      expect(fda.text('productCode')).to eq 'PROD'
      expect(fda.text('fdaUom1')).to eq 'UOM'
      expect(fda.text('countryProduction')).to eq 'CO'
      expect(fda.text('manufacturerId')).to eq 'MID'
      expect(fda.text('shipperId')).to eq 'SHIPPER'
      expect(fda.text('desc1Ci')).to eq 'DESC'
      expect(fda.text('establishmentNo')).to eq 'EST'
      expect(fda.text('containerDimension1')).to eq 'DIM1'
      expect(fda.text('containerDimension2')).to eq 'DIM2'
      expect(fda.text('containerDimension3')).to eq 'DIM3'
      expect(fda.text('contactName')).to eq 'NAME'
      expect(fda.text('contactPhone')).to eq 'PHONE'
      expect(fda.text('cargoStorageStatus')).to eq 'S'

      affirmations = REXML::XPath.each(fda, 'CatFdaEsComplianceList/CatFdaEsCompliance').to_a
      expect(affirmations.length).to eq 2
      aff = affirmations[0]
      expect(aff).not_to be_nil
      expect(aff.text('partNo')).to eq 'PART'
      expect(aff.text('styleNo')).to eq 'PART'
      expect(aff.text('custNo')).to eq 'TEST'
      expect(aff.text('dateEffective')).to eq '20200414'
      expect(aff.text('seqNo')).to eq '1'
      expect(aff.text('fdaSeqNo')).to eq '1'
      expect(aff.text('seqNoEntryOrder')).to eq '1'
      expect(aff.text('complianceCode')).to eq 'AFF'
      expect(aff.text('complianceQualifier')).to eq 'QUAL'

      aff = affirmations[1]
      expect(aff).not_to be_nil
      expect(aff.text('partNo')).to eq 'PART'
      expect(aff.text('styleNo')).to eq 'PART'
      expect(aff.text('custNo')).to eq 'TEST'
      expect(aff.text('dateEffective')).to eq '20200414'
      expect(aff.text('seqNo')).to eq '1'
      expect(aff.text('fdaSeqNo')).to eq '1'
      expect(aff.text('seqNoEntryOrder')).to eq '2'
      expect(aff.text('complianceCode')).to eq 'AF2'
      expect(aff.text('complianceQualifier')).to be_nil

      dot = REXML::XPath.first doc, "part/CatTariffClassList/CatTariffClass/CatPgEsList/CatPgEs[pgAgencyCd = 'NHT']"
      expect(dot).not_to be_nil
      expect(dot.text('partNo')).to eq 'PART'
      expect(dot.text('styleNo')).to eq 'PART'
      expect(dot.text('custNo')).to eq 'TEST'
      expect(dot.text('dateEffective')).to eq '20200414'
      expect(dot.text('seqNo')).to eq '1'
      expect(dot.text('pgCd')).to eq 'DT1'
      expect(dot.text('pgAgencyCd')).to eq 'NHT'
      expect(dot.text('pgProgramCd')).to eq 'DOT'
      expect(dot.text('pgSeqNbr')).to eq '1'

      expect(dot.text('CatNhtsaEs/partNo')).to eq 'PART'
      expect(dot.text('CatNhtsaEs/styleNo')).to eq 'PART'
      expect(dot.text('CatNhtsaEs/custNo')).to eq 'TEST'
      expect(dot.text('CatNhtsaEs/dateEffective')).to eq '20200414'
      expect(dot.text('CatNhtsaEs/seqNo')).to eq '1'
      expect(dot.text('CatNhtsaEs/pgCd')).to eq 'DT1'
      expect(dot.text('CatNhtsaEs/pgAgencyCd')).to eq 'NHT'
      expect(dot.text('CatNhtsaEs/pgSeqNbr')).to eq '1'
      expect(dot.text('CatNhtsaEs/boxNo')).to eq '2A'

      fws = REXML::XPath.first doc, "part/CatTariffClassList/CatTariffClass/CatPgEsList/CatPgEs[pgAgencyCd = 'FWS']"
      expect(fws).not_to be_nil
      expect(fws.text('partNo')).to eq 'PART'
      expect(fws.text('styleNo')).to eq 'PART'
      expect(fws.text('custNo')).to eq 'TEST'
      expect(fws.text('dateEffective')).to eq '20200414'
      expect(fws.text('seqNo')).to eq '1'
      expect(fws.text('pgCd')).to eq 'FW2'
      expect(fws.text('pgAgencyCd')).to eq 'FWS'
      expect(fws.text('pgProgramCd')).to eq 'FWS'
      expect(fws.text('agencyProcessingCd')).to eq 'EDS'
      expect(fws.text('pgSeqNbr')).to eq '1'

      expect(fws.text('CatPgFwsEs/partNo')).to eq 'PART'
      expect(fws.text('CatPgFwsEs/styleNo')).to eq 'PART'
      expect(fws.text('CatPgFwsEs/custNo')).to eq 'TEST'
      expect(fws.text('CatPgFwsEs/dateEffective')).to eq '20200414'
      expect(fws.text('CatPgFwsEs/seqNo')).to eq '1'
      expect(fws.text('CatPgFwsEs/pgCd')).to eq 'FW2'
      expect(fws.text('CatPgFwsEs/pgAgencyCd')).to eq 'FWS'
      expect(fws.text('CatPgFwsEs/pgProgramCd')).to eq 'FWS'
      expect(fws.text('CatPgFwsEs/pgSeqNbr')).to eq '1'
      expect(fws.text('CatPgFwsEs/commonNameGeneral')).to eq 'GEN'
      expect(fws.text('CatPgFwsEs/countryWhereBorn')).to eq 'CO'
      expect(fws.text('CatPgFwsEs/pgaLineValueForeign')).to eq '2025'
      expect(fws.text('CatPgFwsEs/fwsDescriptionCd')).to eq 'CD'
      expect(fws.text('CatPgFwsEs/sourceCharDesc')).to eq 'THE WILD'
      expect(fws.text('CatPgFwsEs/sourceCd')).to eq 'W'
      expect(fws.text('CatPgFwsEs/scientificGenusName1')).to eq 'GENUS'
      expect(fws.text('CatPgFwsEs/scientificSpeciesName1')).to eq 'SPECIES'

      lcy = REXML::XPath.first doc, "part/CatTariffClassList/CatTariffClass/CatPgEsList/CatPgEs[pgAgencyCd = 'APH']"
      expect(lcy).not_to be_nil
      expect(lcy.text('partNo')).to eq 'PART'
      expect(lcy.text('styleNo')).to eq 'PART'
      expect(lcy.text('custNo')).to eq 'TEST'
      expect(lcy.text('dateEffective')).to eq '20200414'
      expect(lcy.text('seqNo')).to eq '1'
      expect(lcy.text('pgCd')).to eq 'AL1'
      expect(lcy.text('pgAgencyCd')).to eq 'APH'
      expect(lcy.text('pgProgramCd')).to eq 'APL'
      expect(lcy.text('pgSeqNbr')).to eq '1'

      expect(lcy.text('CatPgAphisEs/partNo')).to eq 'PART'
      expect(lcy.text('CatPgAphisEs/styleNo')).to eq 'PART'
      expect(lcy.text('CatPgAphisEs/custNo')).to eq 'TEST'
      expect(lcy.text('CatPgAphisEs/dateEffective')).to eq '20200414'
      expect(lcy.text('CatPgAphisEs/seqNo')).to eq '1'
      expect(lcy.text('CatPgAphisEs/pgCd')).to eq 'AL1'
      expect(lcy.text('CatPgAphisEs/pgAgencyCd')).to eq 'APH'
      expect(lcy.text('CatPgAphisEs/pgProgramCd')).to eq 'APL'
      expect(lcy.text('CatPgAphisEs/pgSeqNbr')).to eq '1'
      expect(lcy.text('CatPgAphisEs/productSeqNbr')).to eq '1'
      expect(lcy.text('CatPgAphisEs/importerIndividualName')).to eq 'NAME'
      expect(lcy.text('CatPgAphisEs/importerEmailAddress')).to eq 'EMAIL'
      expect(lcy.text('CatPgAphisEs/importerPhoneNo')).to eq 'PHONE'

      comp = REXML::XPath.first lcy, 'CatPgAphisEs/CatPgAphisEsComponentsList/CatPgAphisEsComponents'
      expect(comp).not_to be_nil
      expect(comp.text('partNo')).to eq 'PART'
      expect(comp.text('styleNo')).to eq 'PART'
      expect(comp.text('custNo')).to eq 'TEST'
      expect(comp.text('dateEffective')).to eq '20200414'
      expect(comp.text('seqNo')).to eq '1'
      expect(comp.text('pgCd')).to eq 'AL1'
      expect(comp.text('pgSeqNbr')).to eq '1'
      expect(comp.text('productSeqNbr')).to eq '1'
      expect(comp.text('componentSeqNbr')).to eq '1'
      expect(comp.text('componentName')).to eq 'COMP'
      expect(comp.text('componentQtyAmt')).to eq '10'
      expect(comp.text('componentUom')).to eq 'M3'
      expect(comp.text('countryHarvested')).to eq 'CN'
      expect(comp.text('percentRecycledMaterialAmt')).to eq '50.5'
      expect(comp.text('commonNameGeneral')).to eq 'GEN NAME'
      expect(comp.text('scientificGenusName')).to eq 'GEN'
      expect(comp.text('scientificSpeciesName')).to eq 'SPEC'

      sci = REXML::XPath.first comp, 'CatPgAphisEsAddScientificList/CatPgAphisEsAddScientific'
      expect(sci).not_to be_nil
      expect(sci).not_to be_nil
      expect(sci.text('partNo')).to eq 'PART'
      expect(sci.text('styleNo')).to eq 'PART'
      expect(sci.text('custNo')).to eq 'TEST'
      expect(sci.text('dateEffective')).to eq '20200414'
      expect(sci.text('seqNo')).to eq '1'
      expect(sci.text('pgCd')).to eq 'AL1'
      expect(sci.text('pgSeqNbr')).to eq '1'
      expect(sci.text('productSeqNbr')).to eq '1'
      expect(sci.text('componentSeqNbr')).to eq '1'
      expect(sci.text('scientificSeqNbr')).to eq '1'
      expect(sci.text('scientificGenusName')).to eq 'GEN2'
      expect(sci.text('scientificSpeciesName')).to eq 'SPEC2'

      epa = REXML::XPath.first doc, "part/CatTariffClassList/CatTariffClass/CatPgEsList/CatPgEs[pgAgencyCd = 'EPA']"
      expect(epa.text('partNo')).to eq 'PART'
      expect(epa.text('styleNo')).to eq 'PART'
      expect(epa.text('custNo')).to eq 'TEST'
      expect(epa.text('dateEffective')).to eq '20200414'
      expect(epa.text('seqNo')).to eq '1'
      expect(epa.text('pgCd')).to eq 'EP5'
      expect(epa.text('pgAgencyCd')).to eq 'EPA'
      expect(epa.text('pgProgramCd')).to eq 'TS1'
      expect(epa.text('pgSeqNbr')).to eq '1'

      expect(epa.text('CatPgEpaEs/partNo')).to eq 'PART'
      expect(epa.text('CatPgEpaEs/styleNo')).to eq 'PART'
      expect(epa.text('CatPgEpaEs/custNo')).to eq 'TEST'
      expect(epa.text('CatPgEpaEs/dateEffective')).to eq '20200414'
      expect(epa.text('CatPgEpaEs/seqNo')).to eq '1'
      expect(epa.text('CatPgEpaEs/pgCd')).to eq 'EP5'
      expect(epa.text('CatPgEpaEs/pgSeqNbr')).to eq '1'
      expect(epa.text('CatPgEpaEs/declarationCd')).to eq 'EP4'
      expect(epa.text('CatPgEpaEs/documentIdCd')).to eq '944'

      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/partNo')).to eq 'PART'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/custNo')).to eq 'TEST'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/dateEffective')).to eq '20200414'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/seqNo')).to eq '1'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/commercialDesc')).to eq 'TARIFF DESC'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/createdDate')).to eq '2020-04-15'

      expect(doc.text('part/CatPenaltyList/CatPenalty/partNo')).to eq 'PART'
      expect(doc.text('part/CatPenaltyList/CatPenalty/custNo')).to eq 'TEST'
      expect(doc.text('part/CatPenaltyList/CatPenalty/dateEffective')).to eq '20200414'
      expect(doc.text('part/CatPenaltyList/CatPenalty/penaltyType')).to eq 'CVD'
      expect(doc.text('part/CatPenaltyList/CatPenalty/caseNo')).to eq 'C123'
    end

    it 'appends default values if defined' do
      allow(subject).to receive(:default_values).and_return({
                                                              'CatCiLine' => { 'approvedBy' => 'nobody', 'c4' => 'BOOM' },
                                                              'CatTariffClass' => { 'assembler' => 'somebody' },
                                                              'CatTariffClassAux' => { 'modifiedBy' => 'somebody' }
                                                            })

      subject.write_tariff_data_to_xml doc, product_data
      expect(doc.text('part/approvedBy')).to eq 'nobody'
      expect(doc.text('part/c4')).to eq 'BOOM'
      expect(doc.text('part/CatTariffClassList/CatTariffClass/assembler')).to eq 'somebody'
      expect(doc.text('part/CatTariffClassAuxList/CatTariffClassAux/modifiedBy')).to eq 'somebody'
    end

    it 'handles EPA Ozone declarations by using a distinct documentIdCd' do
      t = product_data.tariff_data.first

      epa = c::EpaData.new
      epa.epa_code = 'EP1'
      epa.epa_program_code = 'ODS'
      epa.positive_certification = false
      t.epa_data = [epa]

      subject.write_tariff_data_to_xml doc, product_data

      epa = REXML::XPath.first doc, "part/CatTariffClassList/CatTariffClass/CatPgEsList/CatPgEs[pgAgencyCd = 'EPA']"
      expect(epa).not_to be_nil

      expect(epa.text('partNo')).to eq 'PART'
      expect(epa.text('styleNo')).to eq 'PART'
      expect(epa.text('custNo')).to eq 'TEST'
      expect(epa.text('dateEffective')).to eq '20200414'
      expect(epa.text('seqNo')).to eq '1'
      expect(epa.text('pgCd')).to eq 'EP1'
      expect(epa.text('pgAgencyCd')).to eq 'EPA'
      expect(epa.text('pgProgramCd')).to eq 'ODS'
      expect(epa.text('pgSeqNbr')).to eq '1'

      expect(epa.text('CatPgEpaEs/partNo')).to eq 'PART'
      expect(epa.text('CatPgEpaEs/styleNo')).to eq 'PART'
      expect(epa.text('CatPgEpaEs/custNo')).to eq 'TEST'
      expect(epa.text('CatPgEpaEs/dateEffective')).to eq '20200414'
      expect(epa.text('CatPgEpaEs/seqNo')).to eq '1'
      expect(epa.text('CatPgEpaEs/pgCd')).to eq 'EP1'
      expect(epa.text('CatPgEpaEs/pgSeqNbr')).to eq '1'
      expect(epa.text('CatPgEpaEs/declarationCd')).to eq 'EP5'
      expect(epa.text('CatPgEpaEs/documentIdCd')).to eq '942'
    end
  end

  describe 'effective_date' do
    let(:product) { Product.new(updated_at: Time.zone.parse('2020-04-14 01:00')) }

    it "uses given product's updated_at datetime" do
      expect(subject.effective_date(product: product)).to eq Date.new(2020, 4, 13)
    end

    it 'uses given time' do
      # Use a time that crosses the date line (UTC is default time)
      expect(subject.effective_date(effective_date_value: Time.zone.parse('2020-04-14 01:00'))).to eq Date.new(2020, 4, 13)
    end

    it 'falls back to a predefined date when blank' do
      expect(subject.effective_date).to eq Date.new(2014, 1, 1)
    end
  end

  describe 'expiration_date' do
    it 'uses a default date' do
      expect(subject.expiration_date).to eq Date.new(2099, 12, 31)
    end
  end

  describe 'default_expiration_date' do
    it 'uses a hardcoded date' do
      expect(subject.default_expiration_date).to eq Date.new(2099, 12, 31)
    end
  end
end
