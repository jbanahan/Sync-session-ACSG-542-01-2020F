require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::AscenaPoParser do
  let(:header) { ["H","11142016","JUSTICE","","37109","1990","","FRANCHISE","pgroup","82","SUM 2015","","2","12082016","000256","LF PRODUCTS PTE. LTD","Smith","001423","IDSELKAU0105BEK","JIASHAN JSL CASE & BAG CO., LTD","000022","YCHOI","FCA","CHINA (MAINLAND)","OCN","01172017","01172018","HONG KONG","AGS","","","","USD","","","",""] }
  let(:detail) { ["D","","1","","","820799","351152","CB-YING YANG IRRI 3\"","617","SILVER","1","10","","","03010848311526700486","","","0","","2.02","3.46","3.13","7.00","","","","","","","","","","","","","",""] }
  let(:header_2) { ["H","11152016","PEACE",nil,"37109","1991",nil,"FRANCH","qgroup","83","SUM 2016","CCL","4","12092016","000257","MG PRODUCTS PTE. LTD","Jones","001424","JDSELKAU0105BEK","XIASHAN JSL CASE & BAG CO., LTD","000023","ZCHOI","GCA","TAIWAN","PCN","01182017","01182018","KING KONG","BGS",nil,nil,nil,"USD",nil,nil,nil,nil] }
  let(:detail_2) { ["D",nil,"2",nil,nil,"820799","451152","AB-YING YANG IRRI","618","GRAY","2","11",nil,nil,"13010848311526700486",nil,nil,"2",nil,"3.02","4.46","4.13","8.00",nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil] }

  let!(:importer) { Factory(:company, system_code: "ASCENA", importer:true) }

  def convert_pipe_delimited array_of_str
    array_of_str.map { |arr| arr.join("|") }.join("\n")
  end

  before :each do
    # snapshots take a long time so we're stubbing them
    allow_any_instance_of(Order).to receive(:create_snapshot)
    allow_any_instance_of(Product).to receive(:create_snapshot)
  end

  describe "integration folder" do
    it "uses integration folder" do
      expect(described_class.integration_folder).to eq ["www-vfitrack-net/_ascena_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_po"]
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

  describe "parse", :disable_delayed_jobs do
    before(:all) do
      @cdefs = described_class.new.send(:cdefs)
    end

    after(:all) do
      CustomDefinition.delete_all
    end

    def cdefs
      @cdefs
    end

    it "ignores file if PO exists and has revision number greater than the file header's" do
      cdefs = described_class.prep_custom_definitions [:ord_revision]
      ord = Factory(:order, importer: importer, order_number: "ASCENA-37109")
      ord.update_custom_value!(cdefs[:ord_revision], 3)
      described_class.parse(convert_pipe_delimited [header, detail])
      ord.reload
      # If nothign on the order header or no order lines were added, that shows nothign was updated
      # on the order
      expect(ord.order_date).to be_nil
      expect(ord.order_lines.length).to eq 0
    end

    it "creates new orders, order lines, products matching input, product/order snapshots" do
      expect_any_instance_of(Order).to receive(:create_snapshot).with(User.integration,nil,"path")
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration,nil,"path")

      described_class.parse convert_pipe_delimited([header, detail]), bucket: "bucket", key: "path"
      o = Order.where(customer_order_number: "37109").first
      expect(o).not_to be_nil
      expect(o.importer).to eq importer
      expect(o.order_date).to eq Date.new(2016,11,14)
      expect(o.customer_order_number).to eq "37109"
      expect(o.order_number).to eq "ASCENA-37109"
      expect(o.custom_value(cdefs[:ord_selling_channel])).to eq "FRANCHISE"
      expect(o.custom_value(cdefs[:ord_division])).to eq "82"
      expect(o.custom_value(cdefs[:ord_revision])).to eq 2
      expect(o.custom_value(cdefs[:ord_revision_date])).to eq Date.new(2016,12,8)
      expect(o.vendor.system_code).to eq "000256"
      expect(o.vendor.name).to eq "LF PRODUCTS PTE. LTD"
      expect(o.vendor.vendor?).to eq true
      expect(o.custom_value(cdefs[:ord_assigned_agent])).to eq "Smith"
      expect(o.factory.system_code).to eq "001423"
      expect(o.factory.mid).to eq "IDSELKAU0105BEK"
      expect(o.factory.name).to eq "JIASHAN JSL CASE & BAG CO., LTD"
      expect(o.factory.factory?).to eq true
      expect(o.custom_value(cdefs[:ord_selling_agent])).to eq "000022"
      expect(o.custom_value(cdefs[:ord_buyer])).to eq "YCHOI"
      expect(o.terms_of_sale).to eq "FCA"
      expect(o.mode).to eq "OCN"
      expect(o.ship_window_start).to eq Date.new(2017,1,17)
      expect(o.ship_window_end).to eq Date.new(2018,1,17)
      expect(o.fob_point).to eq "HONG KONG"
      expect(o.custom_value(cdefs[:ord_type])).to eq "AGS"
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "path"

      ol = o.order_lines.first
      expect(ol.custom_value(cdefs[:ord_line_department_code])).to eq "JUSTICE"
      expect(ol.custom_value(cdefs[:ord_line_destination_code])).to eq "1990"
      expect(ol.custom_value(cdefs[:ord_line_season])).to eq "SUM 2015"
      expect(ol.country_of_origin).to eq "CHINA (MAINLAND)"
      expect(ol.line_number).to eq 1
      expect(ol.custom_value(cdefs[:ord_line_color])).to eq "617"
      expect(ol.custom_value(cdefs[:ord_line_color_description])).to eq "SILVER"
      expect(ol.custom_value(cdefs[:ord_line_size])).to eq "1"
      expect(ol.custom_value(cdefs[:ord_line_size_description])).to eq "10"
      expect(ol.sku).to eq "03010848311526700486"
      expect(ol.quantity).to eq 0
      expect(ol.price_per_unit).to eq 2.02
      expect(ol.custom_value(cdefs[:ord_line_wholesale_unit_price])).to eq 3.46
      expect(ol.custom_value(cdefs[:ord_line_estimated_unit_landing_cost])).to eq 3.13
      expect(ol.unit_msrp).to eq 7
      expect(ol.unit_of_measure).to eq "Each"

      p = ol.product
      expect(p.importer).to eq importer
      expect(p.custom_value(cdefs[:prod_product_group])).to eq "pgroup"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "820799"
      expect(p.unique_identifier).to eq "ASCENA-820799"
      expect(p.custom_value(cdefs[:prod_vendor_style])).to eq "351152"
      expect(p.name).to eq detail[7]
    end

    it "updates existing orders, replaces order lines, uses existing product" do
      o = Factory(:order, order_number: "ASCENA-37109", importer: importer, customer_order_number: "37109")
      product = Factory(:product, unique_identifier: "ASCENA-820799", importer: importer)
      order_line = Factory(:order_line, order: o, line_number: 2, product: product)

      expect_any_instance_of(Order).to receive(:create_snapshot).with(User.integration,nil,"path 2")
      # The product shouldn't be snapshotted, we didn't update it
      expect_any_instance_of(Product).not_to receive(:create_snapshot)

      described_class.parse convert_pipe_delimited([header_2, detail_2]), bucket: "bucket 2", key: "path 2"

      o.reload
      expect(o.order_date).to eq Date.new(2016,11,15)
      expect(o.custom_value(cdefs[:ord_selling_channel])).to eq "FRANCH"
      expect(o.custom_value(cdefs[:ord_division])).to eq "83"
      expect(o.custom_value(cdefs[:ord_revision])).to eq 4
      expect(o.custom_value(cdefs[:ord_revision_date])).to eq Date.new(2016,12,9)
      expect(o.vendor.system_code).to eq "000257"
      expect(o.vendor.name).to eq "MG PRODUCTS PTE. LTD"
      expect(o.vendor.vendor?).to eq true
      expect(o.custom_value(cdefs[:ord_assigned_agent])).to eq "Jones"
      expect(o.factory.system_code).to eq "001424"
      expect(o.factory.mid).to eq "JDSELKAU0105BEK"
      expect(o.factory.name).to eq "XIASHAN JSL CASE & BAG CO., LTD"
      expect(o.factory.factory?).to eq true
      expect(o.custom_value(cdefs[:ord_selling_agent])).to eq "000023"
      expect(o.custom_value(cdefs[:ord_buyer])).to eq "ZCHOI"
      expect(o.terms_of_sale).to eq "GCA"
      expect(o.mode).to eq "PCN"
      expect(o.ship_window_start).to eq Date.new(2017,1,18)
      expect(o.ship_window_end).to eq Date.new(2018,1,18)
      expect(o.fob_point).to eq "KING KONG"
      expect(o.custom_value(cdefs[:ord_type])).to eq "BGS"
      expect(o.last_file_bucket).to eq "bucket 2"
      expect(o.last_file_path).to eq "path 2"

      expect(o.order_lines.length).to eq 1

      ol = o.order_lines.first
      expect(ol.custom_value(cdefs[:ord_line_department_code])).to eq "PEACE"
      expect(ol.custom_value(cdefs[:ord_line_destination_code])).to eq "1991"
      expect(ol.custom_value(cdefs[:ord_line_season])).to eq "SUM 2016"
      expect(ol.country_of_origin).to eq "TAIWAN"
      expect(ol.line_number).to eq 2
      expect(ol.custom_value(cdefs[:ord_line_color])).to eq "618"
      expect(ol.custom_value(cdefs[:ord_line_color_description])).to eq "GRAY"
      expect(ol.custom_value(cdefs[:ord_line_size])).to eq "2"
      expect(ol.custom_value(cdefs[:ord_line_size_description])).to eq "11"
      expect(ol.sku).to eq "13010848311526700486"
      expect(ol.quantity).to eq 2
      expect(ol.price_per_unit).to eq 3.02
      expect(ol.custom_value(cdefs[:ord_line_wholesale_unit_price])).to eq 4.46
      expect(ol.custom_value(cdefs[:ord_line_estimated_unit_landing_cost])).to eq 4.13
      expect(ol.unit_msrp).to eq 8
      expect(ol.unit_of_measure).to eq "Each"

      p = ol.product
      expect(ol.product).to eq product
      # We don't update anything on the product from the order if it already existed...so this should all be nil
      expect(p.custom_value(cdefs[:prod_product_group])).to be_nil
      expect(p.custom_value(cdefs[:prod_vendor_style])).to be_nil
      expect(p.name).to be_nil
    end

    it "doesn't delete the order line, sends warning email if line is associated with shipment" do
      o = Factory(:order, order_number: "ASCENA-37109", importer: importer, customer_order_number: "37109")
      product = Factory(:product, unique_identifier: "ASCENA-820799", importer: importer)
      order_line = Factory(:order_line, order: o, line_number: 2, product: product)
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "Pinafore"), product: order_line.product)
      PieceSet.create!(quantity: 1, order_line: order_line, shipment_line: sl)

      described_class.parse convert_pipe_delimited([header_2, detail_2]), bucket: "bucket 2", key: "path 2"

      o.reload
      # Make sure a new line wasn't added (was a bug that was in there previously that wasn't skpping shipped lines)
      expect(o.order_lines.length).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).not_to be_nil
      expect(mail.to).to eq([ "ascena_us@vandegriftinc.com" ])
      expect(mail.subject).to eq("Ascena PO # 37109 Lines Already Shipped")
      expect(mail.body).to match(/The following order lines from the Ascena PO # 37109 are already shipping and could not be updated:/)
      expect(mail.attachments.count).to eq 1

      # Make sure the attachment is the data that was processed
      file = mail.attachments.first.read
      expect(file).not_to be_nil
      rows = CSV.parse(file, col_sep: "|", quote_char: "\x00")
      expect(rows.length).to eq 2
      expect(rows[0]).to eq header_2
      expect(rows[1]).to eq detail_2
    end

    it "skips shipped lines, adds other lines from file that weren't shipping" do
      o = Factory(:order, order_number: "ASCENA-37109", importer: importer, customer_order_number: "37109")
      product = Factory(:product, unique_identifier: "ASCENA-820799", importer: importer)
      order_line = Factory(:order_line, order: o, line_number: 2, product: product)
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "Pinafore"), product: order_line.product)
      PieceSet.create!(quantity: 1, order_line: order_line, shipment_line: sl)

      described_class.parse convert_pipe_delimited([header_2, detail, detail_2]), bucket: "bucket 2", key: "path 2"

      o.reload
      expect(o.order_lines.length).to eq 2
      line = o.order_lines.find {|l| l.line_number == 1 }
      expect(line).not_to be_nil
      expect(line.product).to eq product
      expect(line.sku).to eq "03010848311526700486"
    end

    it "skips shipped lines, updates other lines from file that weren't shipping" do
      o = Factory(:order, order_number: "ASCENA-37109", importer: importer, customer_order_number: "37109")
      product = Factory(:product, unique_identifier: "ASCENA-820799", importer: importer)
      order_line = Factory(:order_line, order: o, line_number: 2, product: product)
      order_line_2 = Factory(:order_line, order: o, line_number: 1, product: product)
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "Pinafore"), product: order_line.product)
      PieceSet.create!(quantity: 1, order_line: order_line, shipment_line: sl)

      described_class.parse convert_pipe_delimited([header_2, detail, detail_2]), bucket: "bucket 2", key: "path 2"

      o.reload
      expect(o.order_lines.length).to eq 2
      line = o.order_lines.find {|l| l.line_number == 1 }
      expect(line).not_to be_nil
      expect(line.product).to eq product
      expect(line.sku).to eq "03010848311526700486"
      expect(line).not_to eq order_line_2
    end

    it "skips blank lines in the CSV file" do
      # This would have raised an error previously, so we can pretty much just check that an order was saved and if 
      # so, then it's all good.
      described_class.parse convert_pipe_delimited([header_2, [], ["", ""], detail_2]), bucket: "bucket 2", key: "path 2"

      o = Order.where(customer_order_number: "37109").first
      expect(o).not_to be_nil
    end

    it "doesn't create parties if already present" do
      factory = Factory(:company, system_code: "001423")
      vendor = Factory(:company, system_code: "000256")
      expect{described_class.parse(convert_pipe_delimited [header, detail])}.to_not change(Company,:count)
      expect(Order.first.factory.id).to eq factory.id
      expect(Order.first.vendor.id).to eq vendor.id
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

    it "handles a missing vendor code" do
      header[14] = ""

      described_class.parse(convert_pipe_delimited [header, detail])
      order = Order.first

      expect(order.vendor).to be_nil
    end

    it "does not create a factory if the name is missing" do
      header[19] = nil

      described_class.parse(convert_pipe_delimited [header, detail])
      order = Order.first
      expect(order.factory).to be_nil
    end

    it "does not update factory names to blank if name is missing" do
      factory = Factory(:company, system_code: "001423", name: "Factory")
      header[19] = nil

      described_class.parse(convert_pipe_delimited [header, detail])
      order = Order.first
      expect(order.factory).to eq factory
      factory.reload
      expect(factory.name).to eq "Factory"
    end

    it "updates factory MID if existing mid is blank" do
      factory = Factory(:company, system_code: "001423", name: "Factory")

      described_class.parse(convert_pipe_delimited [header, detail])
      factory.reload

      expect(factory.mid).to eq "IDSELKAU0105BEK"
    end

    it "does not blank an existing factory MID" do
      factory = Factory(:company, system_code: "001423", name: "Factory", mid: "EXISTING")
      header[18] = ""

      described_class.parse(convert_pipe_delimited [header, detail])
      factory.reload

      expect(factory.mid).to eq "EXISTING"
    end
  end

  context "data validation", :disable_delayed_jobs do
    let :header_map do
      subject.map_header header
    end
    let :detail_map do
      subject.map_detail detail
    end
    context "check that methods are called" do
      it "should fail on header validation issue" do
        expect(subject).to receive(:validate_header).with(instance_of(Hash)).and_raise described_class::BusinessLogicError, "some error"
        subject.process_file(convert_pipe_delimited([header_2, detail_2]), key: "file.txt")

        expect(Order.count).to eq 0

        mail = ActionMailer::Base.deliveries.first
        expect(mail).not_to be_nil
        expect(mail.to).to eq ["ascena_us@vandegriftinc.com","edisupport@vandegriftinc.com"]
        expect(mail.subject).to eq "Ascena PO # 37109 Errors"
        expect(mail.body).to include("An error occurred attempting to process Ascena PO # 37109 from the file file.txt.")

        # Make sure the email includes the file that was being processed
        file = mail.attachments.first.read
        expect(file).not_to be_nil
        rows = CSV.parse(file, col_sep: "|", quote_char: "\x00")
        expect(rows.length).to eq 2
        expect(rows[0]).to eq header_2
        expect(rows[1]).to eq detail_2
      end
      it "should fail on detail validation issue" do
        expect(subject).to receive(:validate_detail).with(instance_of(Hash),1).and_raise  described_class::BusinessLogicError, "some error"

        subject.process_file(convert_pipe_delimited [header, detail])

        expect(Order.count).to eq 0
        mail = ActionMailer::Base.deliveries.first
        expect(mail).not_to be_nil
        expect(mail.to).to eq ["ascena_us@vandegriftinc.com","edisupport@vandegriftinc.com"]
        expect(mail.subject).to eq "Ascena PO # 37109 Errors"
      end

      it "should fail when importer not found" do
        importer.destroy

        expect{subject.process_file(convert_pipe_delimited([header, detail]))}.to raise_error "No Importer company found with system code 'ASCENA'."
      end
    end
    context "check validations" do
      it "errors if header order number missing" do
        header[4] = ""
        expect{subject.validate_header(header_map)}.to raise_error "Customer order number missing"
      end

      it "errors if detail part number is missing" do
        detail[5] = ""
        expect{subject.validate_detail(detail_map, 1)}.to raise_error "Part number missing on row 1"
      end

      it "errors if detail quantity is missing" do
        detail[17] = ""
        expect{subject.validate_detail(detail_map, 1)}.to raise_error "Quantity missing on row 1"
      end

      it "errors if detail order line number is missing" do
        detail[2] = ""
        expect{subject.validate_detail(detail_map, 1)}.to raise_error "Line number missing on row 1"
      end

      it "throws no exception if detail price_per_unit is missing and order type is 'NONAGS'" do
        header[28] = "NONAGS"
        detail[19] = ""
        expect{subject.validate_detail(detail_map, 1)}.to_not raise_error
      end
    end
  end
end
