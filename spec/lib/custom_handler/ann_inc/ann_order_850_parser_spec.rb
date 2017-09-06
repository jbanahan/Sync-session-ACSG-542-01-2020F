describe OpenChain::CustomHandler::AnnInc::AnnOrder850Parser do

  let (:standard_edi_data) { IO.read 'spec/fixtures/files/ann_standard_850.edi' }
  let (:prepack_edi_data) { IO.read 'spec/fixtures/files/ann_multi_prepack_850.edi' }
  let! (:ann_taylor) { Factory(:importer, system_code: "ATAYLOR", name: "Ann Taylor")}
  let! (:mid_xref) { DataCrossReference.create! key: "76007", value: "MID1", company: ann_taylor, cross_reference_type: DataCrossReference::MID_XREF}

  describe "parse" do

    let (:cdefs) {
      subject.new.send(:cdefs)
    }

    subject { described_class }

    context "with delayed jobs disabled", :disable_delayed_jobs do

      it "parses an order and saves it" do
        subject.parse standard_edi_data, bucket: "bucket", key: "file.edi"

        order = Order.where(order_number: "ATAYLOR-6232562").first
        expect(order).not_to be_nil

        expect(order.customer_order_number).to eq "6232562"
        expect(order.importer).to eq ann_taylor
        expect(order.order_date).to eq Date.new(2016,11,2)
        expect(order.custom_value(cdefs[:ord_type])).to eq "Standard PO"
        expect(order.custom_value(cdefs[:ord_division])).to eq "ATF"
        expect(order.custom_value(cdefs[:ord_department])).to eq "300"
        expect(order.last_file_path).to eq "file.edi"
        expect(order.last_file_bucket).to eq "bucket"
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201703211251"

        expect(order.vendor).not_to be_nil
        expect(order.vendor.system_code).to eq "ATAYLOR-VN-76007"
        expect(order.vendor.name).to eq "ICON EYEWEAR INC."
        expect(ann_taylor.linked_companies).to include order.vendor

        expect(order.factory).not_to be_nil
        expect(order.factory.system_code).to eq "ATAYLOR-MF-76007"
        expect(order.factory.name).to eq "ICON EYEWEAR INC."
        expect(order.factory.mid).to eq "MID1"
        expect(order.vendor.linked_companies).to include order.factory
        expect(ann_taylor.linked_companies).to include order.factory

        expect(order.order_lines.length).to eq 2    

        line = order.order_lines.first
        expect(line.product).not_to be_nil
        expect(line.product.unique_identifier).to eq "ATAYLOR-337955"
        expect(line.product.name).to eq "icon-m wire aviator"
        expect(line.product.custom_value(cdefs[:prod_part_number])).to eq "337955"
        
        expect(line.line_number).to eq 10
        expect(line.sku).to eq "21930706"
        expect(line.unit_of_measure).to eq "EA"
        expect(line.quantity).to eq 350
        expect(line.price_per_unit).to eq BigDecimal("7.30")
        expect(line.hts).to eq "7117199000"
        expect(line.custom_value(cdefs[:ord_line_color])).to eq "3019"
        expect(line.custom_value(cdefs[:ord_line_color_description])).to eq "Gold"
        expect(line.custom_value(cdefs[:ord_line_size])).to eq "NONE"
        expect(line.custom_value(cdefs[:ord_line_design_fee])).to eq BigDecimal("0.50")
        expect(line.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2017, 5, 1)
        expect(line.custom_value(cdefs[:ord_line_planned_available_date])).to eq Date.new(2017, 5, 15)
        expect(line.custom_value(cdefs[:ord_line_planned_dc_date])).to eq Date.new(2017, 5, 02)


        line = order.order_lines.second

        expect(line.product).not_to be_nil
        expect(line.product.unique_identifier).to eq "ATAYLOR-337955"
        expect(line.product.name).to eq "icon-m wire aviator"
        expect(line.product.custom_value(cdefs[:prod_part_number])).to eq "337955"
        expect(line.product.custom_value(cdefs[:prod_brand])).to eq "ATF"
        snap = line.product.entity_snapshots.first
        expect(snap).not_to be_nil
        expect(snap.user).to eq User.integration
        expect(snap.context).to eq "file.edi"
        
        expect(line.line_number).to eq 20
        expect(line.sku).to eq "21930713"
        expect(line.unit_of_measure).to eq "PK"
        expect(line.quantity).to eq 600
        expect(line.price_per_unit).to eq BigDecimal("3.65")
        expect(line.hts).to eq "7117199000"
        expect(line.custom_value(cdefs[:ord_line_color])).to eq "6526"
        expect(line.custom_value(cdefs[:ord_line_color_description])).to eq "Silver"
        expect(line.custom_value(cdefs[:ord_line_design_fee])).to be_nil
        expect(line.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2017, 5, 1)
        expect(line.custom_value(cdefs[:ord_line_planned_available_date])).to eq Date.new(2017, 5, 15)
        expect(line.custom_value(cdefs[:ord_line_planned_dc_date])).to eq Date.new(2017, 5, 02)

        # This is the prepack specific informaiton that should be gathered.
        expect(line.custom_value(cdefs[:ord_line_units_per_inner_pack])).to eq 2
        expect(line.custom_value(cdefs[:ord_line_prepacks_ordered])).to eq 300
        expect(line.custom_value(cdefs[:ord_line_size])).to eq "NONE"

        expect(order.entity_snapshots.length).to eq 1
        expect(order.entity_snapshots.first.context).to eq "file.edi"
        expect(order.entity_snapshots.first.user).to eq User.integration
      end

      it "parses prepack orders with multiple lines" do
        subject.parse prepack_edi_data, bucket: "bucket", key: "file.edi"

        order = Order.where(order_number: "ATAYLOR-6234355").first
        expect(order).not_to be_nil

        # There's nothing different about prepack / standard orders at the header level

        expect(order.order_lines.length).to eq 1

        line = order.order_lines.first
        expect(line.product.unique_identifier).to eq "ATAYLOR-421122"
        expect(line.line_number).to eq 10
        expect(line.sku).to eq "22633330"
        expect(line.unit_of_measure).to eq "PK"
        expect(line.quantity).to eq 1044
        expect(line.price_per_unit).to eq BigDecimal("9.32")
        expect(line.hts).to eq "6204624021"
        expect(line.custom_value(cdefs[:ord_line_color])).to eq "9102"
        expect(line.custom_value(cdefs[:ord_line_color_description])).to eq "Snowy White"
        expect(line.custom_value(cdefs[:ord_line_design_fee])).to be_nil
        expect(line.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2017, 3, 17)
        expect(line.custom_value(cdefs[:ord_line_planned_available_date])).to eq Date.new(2017, 5, 22)
        expect(line.custom_value(cdefs[:ord_line_planned_dc_date])).to eq Date.new(2017, 5, 8)

        # This is the prepack specific informaiton that should be gathered.
        expect(line.custom_value(cdefs[:ord_line_units_per_inner_pack])).to eq 9
        expect(line.custom_value(cdefs[:ord_line_prepacks_ordered])).to eq 116
        expect(line.custom_value(cdefs[:ord_line_size])).to eq "0 - 16"
      end

      it "updates orders / removing any lines not sent in the EDI file" do
        order = Factory(:order, order_number: "ATAYLOR-6232562", importer: ann_taylor)
        line = order.order_lines.create! line_number: 99, product: Factory(:product)

        subject.parse standard_edi_data

        order.reload

        expect(order.order_lines.map(&:line_number)).not_to include 99
      end

      it "cancels orders" do
        order = Factory(:order, order_number: "ATAYLOR-6232562", importer: ann_taylor)
        subject.parse standard_edi_data.gsub("BEG*04*", "BEG*03*"), key: "file.edi"

        order.reload
        expect(order.closed_by).to eq User.integration
        expect(order.closed_at).not_to be_nil
        expect(order.entity_snapshots.length).to eq 1
        expect(order.entity_snapshots.first.context).to eq "file.edi"
        expect(order.entity_snapshots.first.user).to eq User.integration
      end

      it "re-uses parts" do
        part = Factory(:product, importer: ann_taylor, unique_identifier: "ATAYLOR-337955")

        subject.parse standard_edi_data

        order = Order.where(order_number: "ATAYLOR-6232562").first
        expect(order).not_to be_nil
        expect(order.order_lines.first.product).to eq part

        # The part should also have been updated w/ the style description and snapshotted
        part.reload
        expect(part.name).to eq "icon-m wire aviator"
        expect(part.entity_snapshots.length).to eq 1
      end

      it "re-uses vendors / factories" do
        vendor = Factory(:vendor, system_code: "ATAYLOR-VN-76007")
        factory = Factory(:company, factory: true, system_code: "ATAYLOR-MF-76007", mid: "TEST")

        subject.parse standard_edi_data

        order = Order.where(order_number: "ATAYLOR-6232562").first
        expect(order).not_to be_nil

        expect(order.vendor).to eq vendor
        expect(order.factory).to eq factory
        # It should also update MID values if they differ
        expect(order.factory.mid).to eq "MID1"
      end

      it "errors if ann taylor importer is missing" do
        ann_taylor.destroy

        expect{subject.parse standard_edi_data}.to raise_error "No Ann Taylor importer found with system code 'ATAYLOR'."
      end
    end

    it "delays processing each individual order in the file" do
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:process_transaction).with(instance_of(REX12::Transaction), last_file_bucket: "bucket", last_file_path:"file.edi")

      subject.parse standard_edi_data, bucket: "bucket", key: "file.edi"
    end
  end
end