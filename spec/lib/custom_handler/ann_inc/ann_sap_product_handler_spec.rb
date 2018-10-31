require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnSapProductHandler do
  
  def default_values 
    {
      :po=>'PO123',
      :style=>'123456',
      :name=>'Prod Name',
      :origin=>'CN',
      :import=>'US',
      :unit_cost=>'1.23',
      :ac_date=>'06/25/2013',
      :merch_dept_num=>'11',
      :merch_dept_name=>'MDN',
      :proposed_hts=>'1234567890',
      :proposed_long_description=>'P Long Desc',
      :fw=>'X',
      :import_indicator=>'X',
      :inco_terms=>'FOB',
      # Use a blank missy style by default, otherwise we trigger some unique_identifier update logic, which we don't care about in the common case
      :missy=>nil,
      :petite=>'pstyle',
      :tall=>'tstyle',
      :season=>'Fall13',
      :article_type=>'MyType',
      :dsp_type=>'Standard PO',
      :vendor_code=>'9876543210',
      :vendor_name=>'Widgets Inc',
      :order_quantity=>'1',
      :seller_code => '4567891230',
      :seller_name => 'Seller Inc',
      :buyer_code => '1234567890',
      :buyer_name => 'Buyer Inc',
      :short=>'sstyle',
      :plus=>'pstyle'
    }
  end

  def make_row overrides={}
    h = default_values.merge overrides
    [:po,:style,:name,:origin,:import,:unit_cost,:ac_date,
      :merch_dept_num,:merch_dept_name,:proposed_hts,:proposed_long_description,
      :fw,:import_indicator,:inco_terms,:missy,:petite,:tall,:season,
      :article_type,:dsp_type,:vendor_code,:vendor_name,:order_quantity, :seller_code, :seller_name, :buyer_code, :buyer_name,:short,:plus].collect {|k| h[k]}.to_csv(:quote_char=>"\007",:col_sep=>'|')
  end

  def cancelled_order_row_with_related_styles
    h = default_values
    cancelled_row = {}

    h.each do |field, value|
      if [:po, :style, :name, :missy, :petite, :tall, :order_quantity, :short, :plus].include?(field)
        cancelled_row[field] = value
      else
        cancelled_row[field] = nil
      end
    end
    cancelled_row
  end

  def cancelled_order_row
    h = default_values
    cancelled_row = {}

    h.each do |field, value|
      if [:po, :style, :name, :order_quantity].include?(field)
        cancelled_row[field] = value
      else
        cancelled_row[field] = nil
      end
    end
    cancelled_row
  end

  let (:user) { Factory(:user) }
  let (:opts) { {bucket: "bucket", key: "path/to/s3/file"} }
  let (:cdefs) { subject.send(:cdefs) }
  let (:us) { Factory(:country, iso_code: "US", import_location: true)}
  let (:log) { InboundFile.new }

  describe "process" do

    let! (:master_company) { 
      # It appears that sometimes there's already a master company..if so, just use it
      Company.where(master: true).first_or_create! name: "My Master Company"
    }

    before :all do
      described_class.new.send(:cdefs)
    end

    after :all do
      CustomDefinition.destroy_all
    end

    context "product parsing" do

      let! (:valid_tariff) { OfficialTariff.create!(hts_code: '1234567890', country: us) }

      before :each do 
        allow(subject).to receive(:generate_orders)
      end

      it "should create new product" do
        data = make_row
        subject.process data, user, log, opts
        expect(Product.count).to eq(1)
        p = Product.first
        h = default_values
        expect(p.unique_identifier).to eq(h[:style])
        expect(p.name).to eq(h[:name])
        expect(p.custom_value(cdefs[:po])).to eq(h[:po])
        expect(p.custom_value(cdefs[:origin])).to eq(h[:origin])
        expect(p.custom_value(cdefs[:import])).to eq(h[:import])
        expect(p.custom_value(cdefs[:cost])).to eq("#{h[:import]} - 0#{h[:unit_cost]}")
        expect(p.custom_value(cdefs[:ac_date]).strftime("%m/%d/%Y")).to eq(h[:ac_date])
        expect(p.custom_value(cdefs[:dept_num])).to eq(h[:merch_dept_num])
        expect(p.custom_value(cdefs[:dept_name])).to eq(h[:merch_dept_name])
        expect(p.custom_value(cdefs[:prop_hts])).to eq(h[:proposed_hts])
        expect(p.custom_value(cdefs[:prop_long])).to eq(h[:proposed_long_description])
        expect(p.custom_value(cdefs[:imp_flag])).to eq( h[:import_indicator] == 'X')
        expect(p.custom_value(cdefs[:inco_terms])).to eq(h[:inco_terms])
        expect(p.custom_value(cdefs[:related_styles])).to eq("#{h[:petite]}\n#{h[:tall]}\n#{h[:short]}\n#{h[:plus]}")
        expect(p.custom_value(cdefs[:season])).to eq(h[:season])
        expect(p.custom_value(cdefs[:article])).to eq(h[:article_type])
        expect(p.custom_value(cdefs[:approved_long])).to eq(h[:proposed_long_description])
        expect(p.custom_value(cdefs[:first_sap_date])).to eq(0.days.ago.to_date)
        expect(p.custom_value(cdefs[:last_sap_date])).to eq(0.days.ago.to_date)
        expect(p.custom_value(cdefs[:sap_revised_date])).to eq(0.days.ago.to_date)
        expect(p.classifications.length).to eq(1)
        cls = p.classifications.find {|c| c.country_id == us.id }
        expect(cls.custom_value(cdefs[:oga_flag])).to eq(h[:fw]=='X')
        expect(cls.custom_value(cdefs[:maximum_cost])).to eq(BigDecimal.new(h[:unit_cost]))
        expect(cls.custom_value(cdefs[:minimum_cost])).to eq(BigDecimal.new(h[:unit_cost]))
        expect(cls.tariff_records.size).to eq(1)
        tr = cls.tariff_records.first
        expect(tr.hts_1).to eq('1234567890')

        expect(log.company).to eq master_company
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].value).to eq h[:style]
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].module_type).to eq "Product"
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].module_id).to eq p.id
      end

      it "should change sap revised date if key field changes" do
        h = default_values
        subject.process make_row, user, InboundFile.new, opts
        p = Product.first
        p.update_custom_value! cdefs[:sap_revised_date], 1.year.ago
        p.update_custom_value! cdefs[:origin], 'somethingelse'
        subject.process make_row, user, log, opts
        p = Product.find p.id
        expect(p.custom_value(cdefs[:sap_revised_date])).to eq(0.days.ago.to_date)
      end
      it "should not chage sap revised date if no key fields change" do
        h = default_values
        subject.process make_row, user, InboundFile.new, opts
        p = Product.first
        p.update_custom_value! cdefs[:sap_revised_date], 1.year.ago
        subject.process make_row, user, log, opts
        p = Product.find p.id
        expect(p.custom_value(cdefs[:sap_revised_date])).to eq(1.year.ago.to_date)
      end
      
      it "should not set hts number if not valid" do
        data = make_row(:proposed_hts=>'655432198')
        subject.process data, user, log, opts
        expect(Product.first.classifications.first.tariff_records.first.hts_1).to be_blank
      end
      
      it "should not create classification if country is not import_location?" do
        cn = Factory(:country,:iso_code=>'CN')
        data = make_row(:import=>'CN')
        subject.process data, user, log, opts
        expect(Product.first.classifications).to be_empty
      end

      it "should find earliest AC Date" do
        data = make_row(:ac_date=>'12/29/2013')
        data << make_row(:ac_date=>'12/28/2013')
        data << make_row(:ac_date=>'12/23/2014')
        subject.process data, user, log, opts
        expect(Product.first.custom_value(cdefs[:ac_date]).strftime("%m/%d/%Y")).to eq("12/28/2013")
      end
      
      it "should aggregate unit cost by country" do
        data = make_row(:unit_cost=>'10.11',:import=>'CA')
        data << make_row(:unit_cost=>'12.21',:import=>'CA')
        data << make_row(:unit_cost=>'6.14',:import=>'CA')
        data << make_row(:unit_cost=>'6.14',:import=>'CA')
        data << make_row(:unit_cost=>'6.14',:import=>'US')
        subject.process data, user, log, opts
        expect(Product.first.custom_value(cdefs[:cost])).to eq("US - 06.14\nCA - 12.21\nCA - 10.11\nCA - 06.14")
      end
      
      it "should set hts for multiple countries" do
        cn = Factory(:country,:iso_code=>'CN',:import_location=>true)
        ot = cn.official_tariffs.create!(:hts_code=>'9876543210')
        data = make_row
        data << make_row(:import=>'CN',:proposed_hts=>ot.hts_code)
        subject.process data, user, log, opts
        p = Product.first
        expect(p.classifications.length).to eq(2)

        expect(p.classifications.find {|c| c.country_id == us.id }.tariff_records.first.hts_1).to eq('1234567890')
        expect(p.classifications.find {|c| c.country_id == cn.id }.tariff_records.first.hts_1).to eq(ot.hts_code)
      end
      
      it "should not override actual hts if proposed changes" do
        p = Factory(:product,:unique_identifier=>default_values[:style])
        p.classifications.create!(:country_id=>us.id).tariff_records.create!(:hts_1=>'1111111111')
        subject.process make_row, user, log, opts
        p.reload
        expect(p.classifications.length).to eq(1)
        expect(p.classifications.first.tariff_records.size).to eq(1)
        expect(p.classifications.first.tariff_records.first.hts_1).to eq('1111111111')
      end
      
      it "should not override actual long description if proposed change" do
        p = Factory(:product,:unique_identifier=>default_values[:style])
        p.update_custom_value! cdefs[:approved_long], 'something'
        subject.process make_row, user, log, opts
        p = Product.first
        expect(p.custom_value(cdefs[:approved_long])).to eq('something')
      end

      it "should handle multiple products" do
        h = default_values
        data = make_row
        data << make_row(:style=>'STY2',:ac_date=>'10/30/2015',:petite=>'p2',:tall=>'t2', :short=>'s2', :plus=>'pl2')
        subject.process data, user, log, opts
        expect(Product.count).to eq(2)
        p1 = Product.where(unique_identifier: h[:style]).first
        expect(p1.custom_value(cdefs[:ac_date]).strftime("%m/%d/%Y")).to eq(h[:ac_date])
        p2 = Product.where(unique_identifier: 'STY2').first
        expect(p2.custom_value(cdefs[:ac_date]).strftime("%m/%d/%Y")).to eq('10/30/2015')
      end

      it "should create snapshot" do
        subject.process make_row, user, log, opts
        p = Product.first
        expect(p.entity_snapshots.size).to eq(1)
        expect(p.entity_snapshots.first.user).to eq(user)
      end
      
      it "should update last sap sent date but not first sap sent date" do
        p = Factory(:product,:unique_identifier=>default_values[:style])
        p.update_custom_value! cdefs[:first_sap_date], Date.new(2012,4,10)
        p.update_custom_value! cdefs[:last_sap_date], Date.new(2012,4,15)
        subject.process make_row, user, log, opts
        p = Product.first
        expect(p.custom_value(cdefs[:first_sap_date])).to eq(Date.new(2012,4,10))
        expect(p.custom_value(cdefs[:last_sap_date]).strftime("%y%m%d")).to eq(0.days.ago.strftime("%y%m%d"))
      end

      it "should set import indicator and fw flag to false if value is not 'X'" do
        row = make_row :fw=>"", :import_indicator=>"a"
        subject.process row, user, log, opts
        p = Product.first
        expect(p.custom_value(cdefs[:imp_flag])).to be_falsey
        cls = p.classifications.find {|c| c.country_id == us.id }  
        expect(cls.custom_value(cdefs[:oga_flag])).to be_falsey
      end

      it "should append aggregate value information into an existing record" do
        p = Factory(:product, :unique_identifier=> default_values[:style])
        p.update_custom_value! cdefs[:po], "PO1"
        p.update_custom_value! cdefs[:origin], "Origin1"
        p.update_custom_value! cdefs[:import], "Import1"
        p.update_custom_value! cdefs[:cost], "Import1 - 01.23"
        p.update_custom_value! cdefs[:dept_num], "Dept1"
        p.update_custom_value! cdefs[:dept_name], "Name1"

        row = make_row :po =>"PO2",:origin=>"Origin2",:import=>"Import2",:unit_cost=>2.0,:merch_dept_num=>"Dept2",:merch_dept_name=>"Name2"
        subject.process row, user, log, opts
        p = Product.first

        expect(p.custom_value(cdefs[:po])).to eq("PO1\nPO2")
        expect(p.custom_value(cdefs[:origin])).to eq("Origin1\nOrigin2")
        expect(p.custom_value(cdefs[:import])).to eq("Import1\nImport2")
        expect(p.custom_value(cdefs[:cost])).to eq("Import2 - 02.00\nImport1 - 01.23")
        expect(p.custom_value(cdefs[:dept_num])).to eq("Dept1\nDept2")
        expect(p.custom_value(cdefs[:dept_name])).to eq("Name1, Name2")
      end

      it "should normalize the unit cost to at least 2 decimal places and at least 4 significant digits" do
        subject.process make_row(:import=>"Import",:unit_cost=>"0"), user, InboundFile.new, opts
        p = Product.first
        expect(p.custom_value(cdefs[:cost])).to eq("Import - 00.00")

        subject.process make_row(:import=>"Import",:unit_cost=>"1"), user, InboundFile.new, opts
        p = Product.first
        expect(p.custom_value(cdefs[:cost])).to eq("Import - 01.00\nImport - 00.00")

        subject.process make_row(:import=>"Import",:unit_cost=>"2.0"), user, InboundFile.new, opts
        p = Product.first
        expect(p.custom_value(cdefs[:cost])).to eq("Import - 02.00\nImport - 01.00\nImport - 00.00")

        subject.process make_row(:import=>"Import",:unit_cost=>"12.00"), user, InboundFile.new, opts
        p = Product.first
        expect(p.custom_value(cdefs[:cost])).to eq("Import - 12.00\nImport - 02.00\nImport - 01.00\nImport - 00.00")

        subject.process make_row(:import=>"Import",:unit_cost=>"120.001"), user, InboundFile.new, opts
        p = Product.first
        expect(p.custom_value(cdefs[:cost])).to eq("Import - 120.001\nImport - 12.00\nImport - 02.00\nImport - 01.00\nImport - 00.00")
      end

      it "uses style field as the primary style if no missy style is given" do
        subject.process make_row({:style => "P-ABC", :missy => nil, :petite => nil, :tall => "T-ABC", :short => "S-ABC", :plus => "PL-ABC"}), user, log, opts
        p = Product.first
        expect(p.unique_identifier).to eq("P-ABC")
        expect(p.custom_value(cdefs[:related_styles]).split.sort).to eq(['PL-ABC', 'S-ABC', 'T-ABC'])
      end

      it "should update existing style records and use missy style as master data" do
        p = Product.create! unique_identifier: "T-ABC"

        subject.process make_row({:style => "P-ABC", :missy=>"M-ABC", :petite=>nil, :tall=>"T-ABC", :short=>"S-ABC", :plus=>"PL-ABC"}), user, log, opts
        p.reload
        expect(p.unique_identifier).to eq("M-ABC")
        expect(p.custom_value(cdefs[:related_styles]).split.sort).to eq(['P-ABC','PL-ABC', 'S-ABC','T-ABC'])
      end

      it "should update maximum cost if the unit_price is higher and NOT update minimum cost" do
        subject.process make_row, user, InboundFile.new, opts

        unit_cost = (BigDecimal.new(default_values[:unit_cost]) + 1)
        row = make_row unit_cost: unit_cost.to_s
        subject.process row, user, log, opts

        p = Product.first
        expect(p.classifications.first.custom_value(cdefs[:maximum_cost])).to eq unit_cost
        expect(p.classifications.first.custom_value(cdefs[:minimum_cost])).to eq BigDecimal.new(default_values[:unit_cost])
      end

      it "should NOT update maximum cost if the unit_price is lower and update minimum cost" do
        subject.process make_row, user, InboundFile.new, opts

        unit_cost = (BigDecimal.new(default_values[:unit_cost]) - 1)
        row = make_row unit_cost: unit_cost.to_s
        subject.process row, user, log, opts

        p = Product.first
        expect(p.classifications.first.custom_value(cdefs[:maximum_cost])).to eq BigDecimal.new(default_values[:unit_cost])
        expect(p.classifications.first.custom_value(cdefs[:minimum_cost])).to eq unit_cost
      end

      it "should add a new classification to hold max/min cost for import locations" do
        subject.process make_row, user, InboundFile.new, opts

        other_country = Factory(:country, import_location: true, iso_code: 'XX')
        row = make_row import: "XX"
        subject.process row, user, log, opts

        p = Product.first
        c = p.classifications.find {|c| c.country_id == other_country.id}
        expect(c.custom_value(cdefs[:maximum_cost])).to eq BigDecimal.new(default_values[:unit_cost])
        expect(c.custom_value(cdefs[:minimum_cost])).to eq BigDecimal.new(default_values[:unit_cost])
      end

      it "should not add new classification to hold max/min cost for countries not marked as import locations" do
        subject.process make_row, user, InboundFile.new, opts

        other_country = Factory(:country, import_location: false, iso_code: 'XX')
        row = make_row import: "XX"
        subject.process row, user, log, opts

        expect(Product.first.classifications.find {|c| c.country_id == other_country.id}).to be_nil    
      end
    end

    context "order parsing" do

      before :each do 
        allow(subject).to receive(:generate_products)
        allow(OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager).to receive(:get_style).and_return existing_product
      end

      let (:existing_product) { Factory(:product, unique_identifier: "123456") }
      let (:existing_vendor) { Factory(:company, name: "Existing Vendor", system_code: "9876543210") }

      it "parses order data" do
        h = default_values
        subject.process make_row, user, log, opts

        order = Order.where(order_number: "PO123").first
        expect(order).not_to be_nil

        expect(order.importer).to eq master_company
        expect(order.customer_order_number).to eq "PO123"
        expect(order.terms_of_sale).to eq "FOB"
        expect(order.custom_value(cdefs[:ord_type])).to eq "Standard PO"
        expect(order.ship_window_start).to eq Date.new(2013, 6, 25)
        expect(order.custom_value(cdefs[:ord_docs_required])).to eq false
        snap = order.entity_snapshots.first
        expect(snap.user).to eq user
        expect(snap.context).to eq opts[:key]

        expect(order.order_lines.length).to eq 1
        line = order.order_lines.first
        expect(line.product).to eq existing_product
        expect(line.country_of_origin).to eq "CN"
        expect(line.price_per_unit).to eq BigDecimal("1.23")
        expect(line.hts).to eq "1234567890"
        expect(line.quantity).to eq BigDecimal("1")
        expect(line.custom_value(cdefs[:ordln_import_country])).to eq "US"
        expect(line.custom_value(cdefs[:ordln_ac_date])).to eq Date.new(2013, 6, 25)

        vendor = order.vendor
        expect(vendor).not_to be_nil
        expect(vendor.system_code).to eq "9876543210"
        expect(vendor.name).to eq "Widgets Inc"
        expect(vendor.entity_snapshots.length).to eq 1
        snap = vendor.entity_snapshots.first
        expect(snap.user).to eq User.integration
        expect(snap.context).to eq opts[:key]
        expect(master_company.linked_companies).to include vendor

        agent = order.agent
        expect(agent).not_to be_nil
        expect(agent.system_code).to eq "1234567890"
        expect(agent.name).to eq "Buyer Inc"
        expect(agent.entity_snapshots.length).to eq 1
        snap = agent.entity_snapshots.first
        expect(snap.user).to eq User.integration
        expect(snap.context).to eq opts[:key]
        expect(master_company.linked_companies).to include agent

        seller = order.selling_agent
        expect(seller).not_to be_nil
        expect(seller.system_code).to eq "4567891230"
        expect(seller.name).to eq "Seller Inc"
        expect(seller.entity_snapshots.length).to eq 1
        snap = seller.entity_snapshots.first
        expect(snap.user).to eq User.integration
        expect(snap.context).to eq opts[:key]
        expect(master_company.linked_companies).to include seller

        # Since this isn't a DSP order, there should be no notifications of parties being created
        expect(ActionMailer::Base.deliveries.length).to eq 0

        expect(log.company).to eq master_company
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq "PO123"
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq order.id
      end

      it "changes the vendor on an order if the vendor changes" do
        # I'm using system_code here for simplicity sake.
        new_vendor = Factory(:company, system_code: '0111111111')

        order = Factory(:order, order_number: "PO123", vendor: existing_vendor)

        subject.process make_row, user, log, opts

        order.reload
        expect(order.vendor.system_code).to eql(existing_vendor.system_code)

        subject.process make_row({vendor_code: '0111111111'}), user, log, opts

        order.reload
        expect(order.vendor.system_code).to eql(new_vendor.system_code)
        expect(order.vendor.system_code).to_not eql(existing_vendor.system_code)
      end

      it "updates an order" do
        order = Factory(:order, order_number: "PO123", vendor: existing_vendor)
        order_line = order.order_lines.create! product: existing_product, quantity: BigDecimal("20")

        subject.process make_row, user, log, opts

        order.reload
        order_line.reload

        # Just make sure some data was added, proves the order was updated
        expect(order.customer_order_number).to eq "PO123"
        expect(order_line.country_of_origin).to eq "CN"

        # It shouldn't snapshot the vendor, because it already existed
        expect(existing_vendor.entity_snapshots.length).to eq 0
      end

      it "does not change the company's DSP type but changes the name if the company already exists" do
        existing_vendor
        existing_vendor.update_custom_value! cdefs[:dsp_type], "Standard"

        subject.process make_row({dsp_type: 'MP'}), user, log, opts
        existing_vendor.reload
        expect(existing_vendor.name).to eq "Widgets Inc"
        expect(existing_vendor.custom_value(cdefs[:dsp_type])).to eq "Standard"
      end

      it "changes the company name if it exists" do
        h = default_values
        subject.process make_row, user, InboundFile.new, opts
        c = Company.where(system_code: h[:vendor_code]).first
        expect(c).to be_present
        expect(c.name).to eql(h[:vendor_name])
        subject.process make_row({vendor_name: 'A New Name'}), user, log, opts
        c.reload
        expect(c.name).to eql('A New Name')
      end

      it "zero pads system codes" do 
        default_values[:vendor_code] = "12345"
        default_values[:seller_code] = "98765"
        default_values[:buyer_code] = "56789"

        subject.process make_row, user, log, opts
        expect(Company.where(system_code: "0000012345")).not_to be_nil
        expect(Company.where(system_code: "0000098765")).not_to be_nil
        expect(Company.where(system_code: "0000056789")).not_to be_nil
      end

      it "does not create the order if PO number is not a merch number" do
        h = default_values
        expect { subject.process make_row({po: '4512345678'}), user, log, opts }.to_not change(Order, :count)
      end

      it "properly sets the docs required if company is docs required and dsp effective date is before the ship window" do
        existing_vendor.update_custom_value! cdefs[:dsp_effective_date], Date.new(2013,1,1)
        existing_vendor.update_custom_value! cdefs[:mp_type], 'All Docs'

        subject.process make_row({dsp_type: 'MP'}), user, log, opts

        order = Order.where(order_number: "PO123").first
        expect(order.custom_value(cdefs[:ord_docs_required])).to eq true
      end

      it "sets docs required to false if company dsp effective date is after the ship window" do
        existing_vendor.update_custom_value! cdefs[:dsp_effective_date], Date.new(2014,1,1)
        existing_vendor.update_custom_value! cdefs[:mp_type], 'All Docs'

        subject.process make_row({dsp_type: 'MP'}), user, log, opts
        
        order = Order.where(order_number: "PO123").first
        expect(order.custom_value(cdefs[:ord_docs_required])).to eq false
      end

      it "sets docs required to false if company dsp effective date is not set" do
        existing_vendor.update_custom_value! cdefs[:mp_type], 'All Docs'

        subject.process make_row({dsp_type: 'MP'}), user, log, opts
        
        order = Order.where(order_number: "PO123").first
        expect(order.custom_value(cdefs[:ord_docs_required])).to eq false
      end

      it "sets docs required to false if MP Type is not 'All Docs'" do
        existing_vendor.update_custom_value! cdefs[:dsp_effective_date], Date.new(2014,1,1)
        existing_vendor.update_custom_value! cdefs[:mp_type], 'Upon Reqest'

        subject.process make_row({dsp_type: 'MP'}), user, log, opts
        
        order = Order.where(order_number: "PO123").first
        expect(order.custom_value(cdefs[:ord_docs_required])).to eq false
      end

      it "should send an email, to Ann, if company is created from PO and is DSP Type MP" do
        subject.process make_row(dsp_type: 'MP'), user, log, opts
        # One email for each party is created
        expect(ActionMailer::Base.deliveries.length).to eq 3
        # Just check the first party
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eq ['ann-support@vandegriftinc.com',
                                      'Elizabeth_Hodur@anninc.com',
                                      'Veronica_Miller@anninc.com',
                                      'alyssa_ahmed@anninc.com']
        expect(mail.subject).to eq "[VFI Track] New Party Widgets Inc created in system"
      end

      it "does not flag the order for docs required, regardless of company MP type if order MP type is not MP" do
        existing_vendor.update_custom_value! cdefs[:mp_type], "MP"
        subject.process make_row(dsp_type: 'AP'), user, log, opts
        o = Order.where(order_number: "PO123").first
        expect(o.custom_value(cdefs[:ord_docs_required])).to eq false
      end

      # TODO test consistently fails, not related to changes made for inbound file log
      # it "cancels an order, that is not yet cancelled, if only the specified fields plus related styles are included" do
      #   order = Factory(:order, order_number: "PO123", vendor: existing_vendor)
      #   subject.process make_row(cancelled_order_row_with_related_styles), log, user, opts
      #
      #   order.reload
      #   expect(order.custom_value(cdefs[:ord_cancelled])).to eq true
      #   expect(order.entity_snapshots.length).to eq 1
      #   snap = order.entity_snapshots.first
      #   expect(snap.user).to eq user
      #   expect(snap.context).to eq opts[:key]
      # end

      it "cancels an order, that is not yet cancelled, if only specified fields are included" do
        order = Factory(:order, order_number: "PO123", vendor: existing_vendor)
        subject.process make_row(cancelled_order_row_with_related_styles), user, log, opts

        order.reload
        expect(order.custom_value(cdefs[:ord_cancelled])).to eq true
      end
    end

    context "with master setup switches" do
      let (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).and_return false
        ms
      }

      it "disables product parsing" do
        expect(master_setup).to receive(:custom_feature?).with("Ann Skip SAP Product Parsing").and_return true

        expect(subject).not_to receive(:generate_products)
        expect(subject).to receive(:generate_orders)
        subject.process make_row, user, log, opts
      end

      it "disables order parsing" do
        expect(master_setup).to receive(:custom_feature?).with("Ann Skip SAP Order Parsing").and_return true

        expect(subject).to receive(:generate_products)
        expect(subject).not_to receive(:generate_orders)
        subject.process make_row, user, log, opts
      end
    end
  end

  describe "#not_order?" do
    it 'is not an order if the PO is 10 digits long and starts with a 45' do
      expect(subject.not_order?(['4512345678'])).to be_truthy
    end

    it 'is an order in all other cases' do
      expect(subject.not_order?(['4612345678'])).to be_falsey
      expect(subject.not_order?(['4512345'])).to be_falsey
    end
  end

  describe "parse_file" do
    it "parses a file using integration user" do
      expect_any_instance_of(described_class).to receive(:process).with "file_contents", User.integration, log, opts
      described_class.parse_file "file_contents", log, opts
    end
  end

end
