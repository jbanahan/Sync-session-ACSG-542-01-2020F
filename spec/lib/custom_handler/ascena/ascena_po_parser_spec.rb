require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::AscenaPoParser do
  let(:header) { ["H","11142016","JUSTICE","","37109","1990","","FRANCHISE","pgroup","82","SUM 2015","","2","12082016","000256","LF PRODUCTS PTE. LTD","Smith","001423","IDSELKAU0105BEK","JIASHAN JSL CASE & BAG CO., LTD","000022","YCHOI","FCA","CHINA (MAINLAND)","OCN","01172017","01172018","HONG KONG","AGS","","","","USD","","","",""] }                                                        
  let(:detail) { ["D","","1","","","820799","351152","CB-YING YANG IRRI","617","SILVER","1","10","","","03010848311526700486","","","0","","2.02","3.46","3.13","7.00","","","","","","","","","","","","","",""] }
  let(:header_2) { ["H","11152016","PEACE","","37109","1991","","FRANCH","qgroup","83","SUM 2016","CCL","4","12092016","000257","MG PRODUCTS PTE. LTD","Jones","001424","JDSELKAU0105BEK","XIASHAN JSL CASE & BAG CO., LTD","000023","ZCHOI","GCA","TAIWAN","PCN","01182017","01182018","KING KONG","BGS","","","","USD","","","",""] }
  let(:detail_2) { ["D","","2","","","820799","451152","AB-YING YANG IRRI","618","GRAY","2","11","","","13010848311526700486","","","2","","3.02","4.46","4.13","8.00","","","","","","","","","","","","","",""] }
  
  def convert_pipe_delimited array_of_str
    array_of_str.map { |arr| arr.join("|") }.join("\n")
  end

  describe "integration folder" do
    it "uses integration folder" do
      expect(described_class.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_po"
    end
  end

  describe "date_parse" do
    let(:parser) { described_class.new }

    it "converts MMDDYYYY strings into a Date" do
      expect(parser.date_parse "02122016").to eq Date.new(2016,2,12)
    end

    it "rejects strings with year before 2000" do
      expect(parser.date_parse "02121995").to be nil
    end

    it "rejects strings with day greater than 31" do
      expect(parser.date_parse "02322016").to be nil
    end

    it "rejects strings with month greater than 12" do
      expect(parser.date_parse "15292016").to be nil
    end
  end

  describe "send_error_email" do
    let(:parser) { described_class.new }

    it "extracts and emails data from error hash" do
      parser.errors = {missing_shipped_order_lines: [{vendor: "ACME", ord_num: "12345", line_num: 1, ship_ref: ["Pinafore"]}, {vendor: "Konvenientz", ord_num: "54321", line_num: 2, ship_ref: ["Bounty"]}]}
      file = convert_pipe_delimited([header, detail])
      parser.send_error_email file

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq([ "ascena-us@vandegriftinc.com" ])
      expect(mail.subject).to eq("Error loading Ascena order file for ACME #12345, Konvenientz #54321")
      expect(mail.body).to match(/The following missing order lines have an associated shipment: ACME #12345/)
      expect(mail.attachments.count).to eq 1
      Tempfile.open("Attachment") do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        expect(IO.read t.path).to eq file
      end
    end
  end

  describe "parse" do
    let!(:importer) { Factory(:company, system_code: "ASCE") }
    let!(:cdefs) { described_class.prep_custom_definitions [:ord_line_season,:ord_buyer,:ord_division,:ord_revision,:ord_revision_date,:ord_assigned_agent,
                                                          :ord_selling_agent,:ord_selling_channel,:ord_type,:ord_line_color,:ord_line_color_description,
                                                          :ord_line_department_code,:ord_line_destination_code,:ord_line_size_description,:ord_line_size,
                                                          :ord_line_wholesale_unit_price,:ord_line_estimated_unit_landing_cost,:prod_part_number,
                                                          :prod_product_group,:prod_vendor_style] }
    
    it "ignores file if PO exists and has revision number greater than the file header's" do
      ord = Factory(:order, importer: importer, order_number: "ASCENA-37109")
      ord.update_custom_value!(cdefs[:ord_revision], 3)
      described_class.parse(convert_pipe_delimited [header, detail])
      expect(Order.count).to eq 1
      expect(Order.first.order_date).to be_nil
      expect(OrderLine.count).to eq 0
      expect(Product.count).to eq 0
    end
    
    it "creates new orders, order lines, products matching input, product/order snapshots" do
      described_class.parse convert_pipe_delimited([header, detail]), bucket: "bucket", key: "path"
      expect(Order.count).to eq 1
      expect(OrderLine.count).to eq 1
      expect(Product.count).to eq 1

      o = Order.first
      expect(o.importer).to eq importer
      expect(o.order_date).to eq Date.new(2016,11,14)
      expect(o.customer_order_number).to eq "37109"
      expect(o.order_number).to eq "ASCENA-37109"
      expect(o.get_custom_value(cdefs[:ord_selling_channel]).value).to eq "FRANCHISE"
      expect(o.get_custom_value(cdefs[:ord_division]).value).to eq "82"
      expect(o.get_custom_value(cdefs[:ord_revision]).value).to eq 2
      expect(o.get_custom_value(cdefs[:ord_revision_date]).value).to eq Date.new(2016,12,8)
      expect(o.vendor.system_code).to eq "000256"
      expect(o.vendor.name).to eq "LF PRODUCTS PTE. LTD"
      expect(o.get_custom_value(cdefs[:ord_assigned_agent]).value).to eq "Smith"
      expect(o.factory.system_code).to eq "001423"
      expect(o.factory.mid).to eq "IDSELKAU0105BEK"
      expect(o.factory.name).to eq "JIASHAN JSL CASE & BAG CO., LTD"
      expect(o.get_custom_value(cdefs[:ord_selling_agent]).value).to eq "000022"
      expect(o.get_custom_value(cdefs[:ord_buyer]).value).to eq "YCHOI"
      expect(o.terms_of_sale).to eq "FCA"
      expect(o.mode).to eq "OCN"
      expect(o.ship_window_start).to eq Date.new(2017,1,17)
      expect(o.ship_window_end).to eq Date.new(2018,1,17)
      expect(o.fob_point).to eq "HONG KONG"
      expect(o.get_custom_value(cdefs[:ord_type]).value).to eq "AGS"
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "path"

      ol = o.order_lines.first
      expect(ol.get_custom_value(cdefs[:ord_line_department_code]).value).to eq "JUSTICE"
      expect(ol.get_custom_value(cdefs[:ord_line_destination_code]).value).to eq "1990"
      expect(ol.get_custom_value(cdefs[:ord_line_season]).value).to eq "SUM 2015"
      expect(ol.country_of_origin).to eq "CHINA (MAINLAND)"
      expect(ol.line_number).to eq 1
      expect(ol.get_custom_value(cdefs[:ord_line_color]).value).to eq "617"
      expect(ol.get_custom_value(cdefs[:ord_line_color_description]).value).to eq "SILVER"
      expect(ol.get_custom_value(cdefs[:ord_line_size]).value).to eq "1"
      expect(ol.get_custom_value(cdefs[:ord_line_size_description]).value).to eq "10"
      expect(ol.sku).to eq "03010848311526700486"
      expect(ol.quantity).to eq 0
      expect(ol.price_per_unit).to eq 2.02
      expect(ol.get_custom_value(cdefs[:ord_line_wholesale_unit_price]).value).to eq 3.46
      expect(ol.get_custom_value(cdefs[:ord_line_estimated_unit_landing_cost]).value).to eq 3.13
      expect(ol.unit_msrp).to eq 7
      expect(ol.unit_of_measure).to eq "Each"

      p = ol.product
      expect(p.importer).to eq importer
      expect(p.get_custom_value(cdefs[:prod_product_group]).value).to eq "pgroup"
      expect(p.get_custom_value(cdefs[:prod_part_number]).value).to eq "820799"
      expect(p.unique_identifier).to eq "ASCENA-820799"
      expect(p.get_custom_value(cdefs[:prod_vendor_style]).value).to eq "351152"
      expect(p.name).to eq "CB-YING YANG IRRI"

      expect(o.entity_snapshots.count).to eq 1
      expect(o.entity_snapshots.first.context).to eq "path"
      expect(p.entity_snapshots.count).to eq 1
      expect(p.entity_snapshots.first.context).to eq "path"
    end

    it "updates existing orders, replaces order lines, leaves product unchanged" do
              
      described_class.parse convert_pipe_delimited([header, detail, detail_2]), bucket: "bucket", key: "path"
      described_class.parse convert_pipe_delimited([header_2, detail_2]), bucket: "bucket 2", key: "path 2"
    
      expect(Order.count).to eq 1
      expect(OrderLine.count).to eq 1
      expect(Product.count).to eq 1

      o = Order.first
      expect(o.importer).to eq importer
      expect(o.order_date).to eq Date.new(2016,11,15)
      expect(o.customer_order_number).to eq "37109"
      expect(o.order_number).to eq "ASCENA-37109"
      expect(o.get_custom_value(cdefs[:ord_selling_channel]).value).to eq "FRANCH"
      expect(o.get_custom_value(cdefs[:ord_division]).value).to eq "83"
      expect(o.get_custom_value(cdefs[:ord_revision]).value).to eq 4
      expect(o.get_custom_value(cdefs[:ord_revision_date]).value).to eq Date.new(2016,12,9)
      expect(o.vendor.system_code).to eq "000257"
      expect(o.vendor.name).to eq "MG PRODUCTS PTE. LTD"
      expect(o.get_custom_value(cdefs[:ord_assigned_agent]).value).to eq "Jones"
      expect(o.factory.system_code).to eq "001424"
      expect(o.factory.mid).to eq "JDSELKAU0105BEK"
      expect(o.factory.name).to eq "XIASHAN JSL CASE & BAG CO., LTD"
      expect(o.get_custom_value(cdefs[:ord_selling_agent]).value).to eq "000023"
      expect(o.get_custom_value(cdefs[:ord_buyer]).value).to eq "ZCHOI"
      expect(o.terms_of_sale).to eq "GCA"
      expect(o.mode).to eq "PCN"
      expect(o.ship_window_start).to eq Date.new(2017,1,18)
      expect(o.ship_window_end).to eq Date.new(2018,1,18)
      expect(o.fob_point).to eq "KING KONG"
      expect(o.get_custom_value(cdefs[:ord_type]).value).to eq "BGS"
      expect(o.last_file_bucket).to eq "bucket 2"
      expect(o.last_file_path).to eq "path 2"

      ol = o.order_lines.first
      expect(ol.get_custom_value(cdefs[:ord_line_department_code]).value).to eq "PEACE"
      expect(ol.get_custom_value(cdefs[:ord_line_destination_code]).value).to eq "1991"
      expect(ol.get_custom_value(cdefs[:ord_line_season]).value).to eq "SUM 2016"
      expect(ol.country_of_origin).to eq "TAIWAN"
      expect(ol.line_number).to eq 2
      expect(ol.get_custom_value(cdefs[:ord_line_color]).value).to eq "618"
      expect(ol.get_custom_value(cdefs[:ord_line_color_description]).value).to eq "GRAY"
      expect(ol.get_custom_value(cdefs[:ord_line_size]).value).to eq "2"
      expect(ol.get_custom_value(cdefs[:ord_line_size_description]).value).to eq "11"
      expect(ol.sku).to eq "13010848311526700486"
      expect(ol.quantity).to eq 2
      expect(ol.price_per_unit).to eq 3.02
      expect(ol.get_custom_value(cdefs[:ord_line_wholesale_unit_price]).value).to eq 4.46
      expect(ol.get_custom_value(cdefs[:ord_line_estimated_unit_landing_cost]).value).to eq 4.13
      expect(ol.unit_msrp).to eq 8
      expect(ol.unit_of_measure).to eq "Each"

      p = ol.product
      expect(p.importer).to eq importer
      expect(p.get_custom_value(cdefs[:prod_product_group]).value).to eq "pgroup"
      expect(p.get_custom_value(cdefs[:prod_part_number]).value).to eq "820799"
      expect(p.unique_identifier).to eq "ASCENA-820799"
      expect(p.get_custom_value(cdefs[:prod_vendor_style]).value).to eq "351152"
      expect(p.name).to eq "CB-YING YANG IRRI"
      
      expect(o.entity_snapshots.count).to eq 2
      expect(o.entity_snapshots.last.context).to eq "path 2"
      expect(p.entity_snapshots.count).to eq 1
      expect(p.entity_snapshots.first.context).to eq "path"
    end
    
    it "doesn't delete the order line, sends warning email if line is associated with shipment" do
      described_class.parse convert_pipe_delimited([header, detail, detail_2]), bucket: "bucket", key: "path"
      ol = OrderLine.first
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "Pinafore"), product: ol.product)
      PieceSet.create!(quantity: 1, order_line: ol, shipment_line: sl)
      described_class.parse convert_pipe_delimited([header_2, detail_2]), bucket: "bucket 2", key: "path 2"

      expect(OrderLine.count).to eq 2
      
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq([ "ascena-us@vandegriftinc.com" ])
      expect(mail.subject).to eq("Error loading Ascena order file for MG PRODUCTS PTE. LTD #ASCENA-37109")
      expect(mail.body).to match(/The following missing order lines have an associated shipment: MG PRODUCTS PTE/)
      expect(mail.attachments.count).to eq 1
    end

    context "with pre-existing data" do
      it "doesn't create factory if already present" do
        factory = Factory(:company, system_code: "001423")
        described_class.parse(convert_pipe_delimited [header, detail])
        expect(Order.first.factory.id).to eq factory.id
      end

      it "doesn't create vendor if already present" do
        vendor = Factory(:company, system_code: "000256")
        described_class.parse(convert_pipe_delimited [header, detail])
        expect(Order.first.vendor.id).to eq vendor.id
      end
    end

    it "sets price_per_unit to 0 for each line and leaves other prices blank if order type is 'NONAGS'" do
      header[28] = "NONAGS"
      described_class.parse(convert_pipe_delimited [header, detail])
      ol = Order.first.order_lines.first
      
      expect(ol.price_per_unit).to eq 0
      expect(ol.get_custom_value(cdefs[:ord_line_wholesale_unit_price]).value).to be_nil
      expect(ol.get_custom_value(cdefs[:ord_line_estimated_unit_landing_cost]).value).to be_nil
      expect(ol.unit_msrp).to be_nil
    end

    context "data validation" do
      it "errors if header order number missing" do
        header[4] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Customer order number missing on row 1"
      end

      it "errors if header vendor system_code is missing" do
        header[14] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Vendor system code missing on row 1"
      end

      it "errors if detail part number is missing" do
        detail[5] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Part number missing on row 2"
      end

      it "errors if detail quantity is missing" do
        detail[17] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Quantity missing on row 2"
      end

      it "errors if detail order line number is missing" do
        detail[2] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Line number missing on row 2"
      end

      it "errors if detail price_per_unit is missing and order type isn't 'NONAGS'" do
        detail[19] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.to raise_error "Price per unit missing on row 2"
      end

      it "throws no exception if detail price_per_unit is missing and order type is 'NONAGS'" do
        header[28] = "NONAGS"
        detail[19] = ""
        expect { described_class.parse(convert_pipe_delimited [header, detail]) }.not_to raise_error
      end
    end
  end

end