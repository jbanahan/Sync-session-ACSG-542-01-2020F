require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewDrawbackImportProcessorV2 do
  describe '#parse' do
    it 'should validate internal integrity and fail on missed validation' do
      d = double('data')
      described_class.should_receive(:build_data_structure).with(d).and_raise 'some error'
      described_class.should_not_receive(:process_data)

      expect{described_class.parse(d,double('user'))}.to raise_error 'some error'
    end
    it 'should process_data if integrity passes' do
      d = double('data')
      u = double('user')
      ds = double('data_structure')

      described_class.should_receive(:build_data_structure).with(d).and_return(ds)
      described_class.should_receive(:process_data).with(ds,u).and_return []

      described_class.parse(d,u)
    end
    it 'should email log to user' do
      u = Factory(:user,email:'sample@vfitrack.net')
      ds = double('data_structure')
      d = double('data')

      described_class.should_receive(:build_data_structure).with(d).and_return(ds)
      described_class.should_receive(:process_data).with(ds,u).and_return ['bad']

      mail_obj = double('mail')
      mail_obj.stub(:deliver!)
      OpenMailer.should_receive(:send_simple_text).with(
        u.email,
        "J Crew Drawback Import V2 Error Log",
        "**J Crew Drawback Import V2 Error Log**\nbad"
      ).and_return(mail_obj)

      described_class.parse(d,u)
    end
  end

  describe '#process_data' do
    it "should process entries" do
      content_1 = double('hash content 1')
      content_2 = double('hash content 2')
      h = {'12345678900'=>content_1,'99999999999'=>content_2}
      u = double('user')
      described_class.should_receive(:find_used_entries).with(h.keys).and_return []
      described_class.should_receive(:process_entry).with(h.keys.first,h.values.first)
      described_class.should_receive(:process_entry).with(h.keys.last,h.values.last)

      expect(described_class.process_data(h,u)).to be_empty

    end
    it 'should fail on used entries' do
      h = {'12345678900'=>{},'99999999999'=>{}}
      u = double('user')
      described_class.should_receive(:find_used_entries).with(h.keys).and_return ['12345678900']

      expect(described_class.process_data(h,u)).to eq ['Entries already have drawback lines: ["12345678900"].']
    end
    it 'should fail with compact message if more than 10 entries used' do
      h = {'12345678900'=>{},'99999999999'=>{}}
      u = double('user')
      described_class.should_receive(:find_used_entries).with(h.keys).and_return (1..11).to_a.collect {|x| x.to_s}

      expect(described_class.process_data(h,u)).to eq ['11 entries already have drawback lines.']
    end
  end

  describe '#find_used_entries' do
    it 'should find used entries' do
      Factory(:drawback_import_line,entry_number:'12345678901')
      expect(described_class.find_used_entries(['12345678901','10987654321'])).to eq ['12345678901']
    end
  end

  describe '#process_entry' do
    before :each do
      mo = double('mail_obj')
      mo.stub(:deliver!)
      OpenMailer.stub(:send_simple_text).and_return(mo)
      @crew = Factory(:company,alliance_customer_number:'JCREW')
      # create underlying entry
      OpenChain::CustomHandler::KewillEntryParser.parse(IO.read('spec/support/bin/j_crew_drawback_import_v2_entry.json'),imaging: false)
    end
    it 'should create drawback_import_lines' do
      u = Factory(:master_user)
      log = described_class.parse(IO.read('spec/support/bin/j_crew_drawback_import_v2_sample.csv'),u)
      expect(log).to be_empty
      expect(DrawbackImportLine.count).to eq 317

      ent = Entry.first

      found = DrawbackImportLine.where(
        entry_number: '31604364559',
        part_number: '24892BR58040',
        quantity: 40
      )
      expect(found.size).to eq 1
      dil = found.first
      expect(dil.import_date.strftime("%Y-%m-%d")).to eq ent.arrival_date.strftime("%Y-%m-%d")
      expect(dil.received_date.strftime("%Y-%m-%d")).to eq ent.arrival_date.strftime("%Y-%m-%d")
      expect(dil.port_code).to eq ent.entry_port_code
      expect(dil.box_37_duty).to eq ent.total_duty
      expect(dil.box_40_duty).to eq ent.total_duty_direct
      expect(dil.total_mpf).to eq ent.mpf
      expect(dil.country_of_origin_code).to eq 'CN'
      expect(dil.hts_code).to eq '6204624056'
      expect(dil.description).to eq 'SHORTS,COTTON,WOMEN\'S'
      expect(dil.unit_of_measure).to eq 'PCS'
      expect(dil.unit_price).to eq 11.44 #first sale value
      expect(dil.rate).to eq BigDecimal("0.166")
      expect(dil.duty_per_unit).to eq BigDecimal("1.89904")
      expect(dil.compute_code).to eq '7'
      expect(dil.ocean).to eq true
      expect(dil.total_invoice_value).to eq BigDecimal("3889.6")
      expect(dil.importer_id).to eq @crew.id
    end
    it "should fail if units don't match entry" do
      u = Factory(:master_user)
      data = IO.read('spec/support/bin/j_crew_drawback_import_v2_sample.csv')
      data.gsub!(
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48',
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,341,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,41,50,12/23/2009,Sea,Sea,$14.48'
      )
      log = described_class.parse(data,u)
      expect(log).to eq ['Entry 31604364559, PO 4016516, Part 24892, Quantity 341 not found.']
      expect(DrawbackImportLine.count).to eq 0
    end
    it "should fail if line isn't found" do
      u = Factory(:master_user)
      CommercialInvoiceLine.where(part_number:'24892',po_number:'4016516').first.destroy
      log = described_class.parse(IO.read('spec/support/bin/j_crew_drawback_import_v2_sample.csv'),u)
      expect(log).to eq ['Entry 31604364559, PO 4016516, Part 24892, Quantity 340 not found.']
      expect(DrawbackImportLine.count).to eq 0
    end
  end

  describe '#build_data_structure' do
    before :each do
      @data = IO.read('spec/support/bin/j_crew_drawback_import_v2_sample.csv')
    end
    it 'should create master data object' do
      # should be a hash of entries keyed on entry number
      # which contains an array of hashes keyed on po-part
      # which contains and array of DATA_ROW_STRUCTs
      main_hash = described_class.build_data_structure(@data)

      expect(main_hash.size).to eq 1
      po_part_hash = main_hash['31604364559']
      expect(po_part_hash.size).to eq 20
      struct_array = po_part_hash['4016516~24892']
      expect(struct_array.size).to eq 7
      struct_1 = struct_array.first

      expect(struct_1.file_line_number).to eq 2
      expect(struct_1.entry_number).to eq '31604364559'
      expect(struct_1.entry_mbol).to eq 'APLU031970557'
      expect(struct_1.entry_arrival_date).to eq Date.new(2010,1,10)
      expect(struct_1.entry_po).to eq '4016516'
      expect(struct_1.entry_part).to eq '24892'
      expect(struct_1.entry_coo).to eq 'CN'
      expect(struct_1.entry_units).to eq 340
      expect(struct_1.crew_mbol).to eq 'APLU031970557'
      expect(struct_1.crew_po).to eq '4016516'
      expect(struct_1.crew_mode).to eq 'SEA'
      expect(struct_1.crew_style).to eq '24892'
      expect(struct_1.crew_order_line_number).to eq '102'
      expect(struct_1.crew_asn_pieces).to eq 40
      expect(struct_1.crew_order_pieces).to eq 50
      expect(struct_1.crew_ship_date).to eq Date.new(2009,12,23)
      expect(struct_1.crew_unit_cost).to eq BigDecimal('14.48')
    end
    it 'should fail if Sum of line quantities grouped by style/po does not match Invoice Line Units' do
      @data.gsub!('24892BR58040,102,40','24892BR58040,102,41')
      expect{described_class.build_data_structure(@data)}.to raise_error "Expected entry 31604364559 PO 4016516 Style 24892 to have 340 pieces but found 341."
    end
    it 'should fail if Invoice Line PO Number does not match PO number' do
      @data.gsub!(
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48',
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,401651X,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48'
      )
      expect{described_class.build_data_structure(@data)}.to raise_error "Error on line 2: Expected PO 4016516 found 401651X."
    end
    it 'should fail if Invoice Line Part Number does not match Part number' do
      @data.gsub!(
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48',
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,2489X,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48'
      )
      expect{described_class.build_data_structure(@data)}.to raise_error "Error on line 2: Expected Style 24892 found 2489X."
    end
    it 'should fail if Master Bills does not match Mawb/BillofLading' do
      @data.gsub!(
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48',
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU03197055X,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48'
      )
      expect{described_class.build_data_structure(@data)}.to raise_error "Error on line 2: Expected Master Bill APLU031970557 found APLU03197055X."
    end
    it 'should fail if POShipDate is not less than Arrival Date and mode is sea' do
      @data.gsub!(
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2010,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48',
        '436455,31604364559,APLU031970557,NULL,JCREW,1/10/2009,4016516,24892,CN,340,APLU031970557,4016516,2,SEA,24892,BR5804,0,NULL,24892BR58040,102,40,50,12/23/2009,Sea,Sea,$14.48'
      )
      expect{described_class.build_data_structure(@data)}.to raise_error "Error on line 2: Ship date 2009-12-23 is after arrival date 2009-01-10."
    end
  end
end
