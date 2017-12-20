describe OpenChain::CustomHandler::Generic850ParserFramework do

  let (:standard_transaction_data) { IO.read 'spec/fixtures/files/talbots.edi'}
  let (:prepack_transaction_data) { IO.read 'spec/fixtures/files/burlington_850_prepack.edi'}
  let (:user) { Factory(:user) }

  describe "process_transaction" do

    FakeStandard850Parser = Class.new(OpenChain::CustomHandler::Generic850ParserFramework) {

      def initialize
        super(self.class.configuration)
      end
      
      def prep_importer
        Company.where(importer: true, system_code: "Test", name: "Test").first_or_create!
      end

      def line_level_segment_list
        ["PO1", "PO4"]
      end

      def standard_style po1, all_line_segments
        find_segment_qualified_value(po1, "VA")
      end

      def update_standard_product product, all_edi_segments, po1, all_line_segments
        product.name = "TEST"
        true
      end

      def process_order_header user, order, all_edi_segments
        order.season = "TEST"
      end

      def process_standard_line(order, po1, all_line_segments, product)
        order.order_lines.create! product: product
      end

      def self.configuration
        # This method is here to allow for an easy way to provide customized configuration
        {}
      end

    }

    FakePrepack850Parser = Class.new(FakeStandard850Parser) {

      def line_level_segment_list
        ["PO1", "PO4", "SDQ", "SLN", "PEN", "TC2", "CTP", "SAC", "CUR"]
      end

      def prepack_segment_list
        ["SLN", "PEN", "TC2", "CTP", "SAC", "CUR"]
      end

      def standard_style po1, all_line_segments
        find_segment_qualified_value(po1, "IN")
      end

      def prepack_style(po1_segment, all_line_segments, sln_segment, all_sln_segments)
        find_segment_qualified_value(sln_segment, "IN")
      end

      def update_prepack_product(product, all_edi_segments, po1_segment, all_line_segments, sln_segment, all_sln_segments)
        product.name = "PREPACK"
        true
      end

      def process_prepack_line(order, po1, sln, all_subline_segments, product)
        order.order_lines.create! product: product
      end
    }

    FakeExploadedPrepack850Parser = Class.new(FakePrepack850Parser) {
      def self.configuration
        # This method is here to allow for an easy way to provide customized configuration
        {explode_prepacks: true}
      end
    }

    FakeExploadedVariantPrepack850Parser = Class.new(FakeExploadedPrepack850Parser) {

      def prepack_variant_identifier po1_segment, line_segments, sln_segment, sln_segments
        find_segment_qualified_value(sln_segment, "UP")
      end

      def update_prepack_product(product, all_edi_segments, po1_segment, all_line_segments, sln_segment, all_sln_segments)
        product.name = "PREPACK"

        product.variants.build variant_identifier: prepack_variant_identifier(nil, nil, sln_segment, nil)
        true
      end

      def process_prepack_line(order, po1, sln, all_subline_segments, product)
        variant_id = prepack_variant_identifier(nil, nil, sln, nil)
        variant = product.variants.find {|v| v.variant_identifier == variant_id}
        order.order_lines.create! product: product, variant: variant
      end
    }


    context "with standard order lines" do
      
      subject { FakeStandard850Parser.new }

      let (:transaction) { REX12.each_transaction(StringIO.new(standard_transaction_data)).first }

      it "parses a standard 850" do
        subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

        # It should have created an importer
        importer = Company.where(importer: true, system_code: "Test").first
        expect(importer).not_to be_nil

        product = Product.where(importer_id: importer.id, unique_identifier: "Test-53903309P/FL15").first
        expect(product).not_to be_nil
        expect(product.name).to eq "TEST"
        # It should snapshot the product because be default we tell it the product was updated
        expect(product.entity_snapshots.length).to eq 1
        expect(product.entity_snapshots.first.user).to eq user
        expect(product.entity_snapshots.first.context).to eq "path"

        order = Order.where(importer_id: importer.id).first
        expect(order.order_number).to eq "Test-5086819"
        expect(order.customer_order_number).to eq "5086819"
        expect(order.season).to eq "TEST"
        expect(order.last_file_bucket).to eq "bucket"
        expect(order.last_file_path).to eq "path"
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201508042223"

        expect(order.entity_snapshots.length).to eq 1
        expect(order.entity_snapshots.first.user).to eq user
        expect(order.entity_snapshots.first.context).to eq "path"

        expect(order.order_lines.length).to eq 3
        line = order.order_lines.first

        expect(line.product).to eq product
      end

      it "handles cancelled orders" do
        t = REX12.each_transaction(StringIO.new(standard_transaction_data.gsub("BEG*07*", "BEG*01*"))).first

        subject.process_transaction(user, t, last_file_bucket: "bucket", last_file_path: "path")

        importer = Company.where(importer: true, system_code: "Test").first
        expect(importer).not_to be_nil

        # It should not create products when an order is cancelled
        expect(Product.all.length).to eq 0

        order = Order.where(importer_id: importer.id).first
        expect(order).not_to be_nil
        expect(order.closed_by).to eq user

        expect(order.entity_snapshots.length).to eq 1
      end

      it "errors if order is already shipping" do
        expect_any_instance_of(Order).to receive(:shipping?).and_return true

        expect{ subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")}.to raise_error "PO # '5086819' is already shipping and cannot be updated."
      end

      it "rejects orders that have isa dates older than existing orders" do
        importer = subject.importer
        order = Order.create!(importer_id: importer.id, order_number: "Test-5086819", last_exported_from_source: Date.new(2017, 9, 1))

        subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

        order.reload
        expect(order.customer_order_number).to be_nil
      end
    end

    context "with configuration changes" do

      subject { FakeStandard850Parser }
      let (:transaction) { REX12.each_transaction(StringIO.new(standard_transaction_data)).first }

      it "allows for different cancellation codes" do
        expect(subject).to receive(:configuration).and_return({canceled_order_transmission_code: 10})

        t = REX12.each_transaction(StringIO.new(standard_transaction_data.gsub("BEG*07*", "BEG*10*"))).first

        subject.new.process_transaction(user, t, last_file_bucket: "bucket", last_file_path: "path")

        order = Order.where(order_number: "Test-5086819").first
        expect(order).not_to be_nil
        expect(order.closed_by).to eq user
      end

      it "allows for not creating prefixes on products and orders created" do
        expect(subject).to receive(:configuration).and_return({prefix_identifiers_with_system_codes: false})

        subject.new.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

        expect(Product.where(unique_identifier: "53903309P/FL15").first).not_to be_nil
        expect(Order.where(order_number: "5086819").first).not_to be_nil
      end

      it "allows for updating orders that are already shipped" do
        expect_any_instance_of(Order).not_to receive(:shipping?)
        expect(subject).to receive(:configuration).and_return({allow_updates_to_shipping_orders: true})

        expect{ subject.new.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")}.not_to raise_error
      end

      context "with revision custom values" do 

        subject {
          Class.new(FakeStandard850Parser) do 
            include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

            def cdef_uids
              [:ord_revision, :ord_revision_date]
            end
          end
        }

        it "allows for tracking order by revision custom values" do
          expect(subject).to receive(:configuration).and_return({track_order_by: :revision})
          parser = subject.new

          t = REX12.each_transaction(StringIO.new(standard_transaction_data.gsub("BEG*07*SA*5086819**20150202", "BEG*07*SA*5086819*5*20150202"))).first
       
          parser.process_transaction(user, t, last_file_bucket: "bucket", last_file_path: "path")

          order = Order.where(order_number: "Test-5086819").first
          expect(order).not_to be_nil

          expect(order.custom_value(parser.cdefs[:ord_revision])).to eq 5
          expect(order.custom_value(parser.cdefs[:ord_revision_date])).to eq ActiveSupport::TimeZone["America/New_York"].now.to_date
        end

        it "rejects updating orders based on revision number" do
          expect(subject).to receive(:configuration).and_return({track_order_by: :revision})
          parser = subject.new
          importer = parser.importer

          t = REX12.each_transaction(StringIO.new(standard_transaction_data.gsub("BEG*07*SA*5086819**20150202", "BEG*07*SA*5086819*5*20150202"))).first
       
          order = Order.create!(importer_id: importer.id, order_number: "Test-5086819")
          order.update_custom_value! parser.cdefs[:ord_revision], 10

          parser.process_transaction(user, t, last_file_bucket: "bucket", last_file_path: "path")

          order.reload

          # Revision date will be nil because it the file wasn't processed, since it's revision is older than the order in the DB
          expect(order.custom_value(parser.cdefs[:ord_revision_date])).to be_nil
        end
      end
    
    end

    context "with prepack order lines" do
      subject { FakePrepack850Parser.new }

      let (:transaction) { REX12.each_transaction(StringIO.new(prepack_transaction_data)).first }

      it "parses an 850 that has prepack lines, without exploding the lines" do
        subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

        # It should have created an importer
        importer = Company.where(importer: true, system_code: "Test").first
        expect(importer).not_to be_nil

        product = Product.where(importer_id: importer.id, unique_identifier: "Test-PO3636924LN10").first
        expect(product).not_to be_nil
        # Because we're not exploading prepacks, the prepack specific parser method shouldn't be utilized
        expect(product.name).to eq "TEST"
        # It should snapshot the product because be default we tell it the product was updated
        expect(product.entity_snapshots.length).to eq 1
        expect(product.entity_snapshots.first.user).to eq user
        expect(product.entity_snapshots.first.context).to eq "path"

        order = Order.where(importer_id: importer.id).first
        expect(order.order_number).to eq "Test-364225101"
        expect(order.customer_order_number).to eq "364225101"
        expect(order.season).to eq "TEST"
        expect(order.last_file_bucket).to eq "bucket"
        expect(order.last_file_path).to eq "path"
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201607250954"

        expect(order.entity_snapshots.length).to eq 1
        expect(order.entity_snapshots.first.user).to eq user
        expect(order.entity_snapshots.first.context).to eq "path"

        expect(order.order_lines.length).to eq 1
        line = order.order_lines.first

        expect(line.product).to eq product
      end

      context "with explode_prepacks" do
        subject { FakeExploadedPrepack850Parser.new }

        it "parses an 850 that has prepack lines, exploading the lines" do
          subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

          # It should have created an importer
          importer = Company.where(importer: true, system_code: "Test").first
          expect(importer).not_to be_nil

          product = Product.where(importer_id: importer.id, unique_identifier: "Test-14734003").first
          expect(product).not_to be_nil
          # Because we're not exploading prepacks, the prepack specific parser method shouldn't be utilized
          expect(product.name).to eq "PREPACK"
          # It should snapshot the product because be default we tell it the product was updated
          expect(product.entity_snapshots.length).to eq 1
          expect(product.entity_snapshots.first.user).to eq user
          expect(product.entity_snapshots.first.context).to eq "path"

          order = Order.where(importer_id: importer.id).first
          expect(order.order_number).to eq "Test-364225101"
          expect(order.customer_order_number).to eq "364225101"
          expect(order.season).to eq "TEST"
          expect(order.last_file_bucket).to eq "bucket"
          expect(order.last_file_path).to eq "path"
          expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201607250954"

          expect(order.entity_snapshots.length).to eq 1
          expect(order.entity_snapshots.first.user).to eq user
          expect(order.entity_snapshots.first.context).to eq "path"

          expect(order.order_lines.length).to eq 2
          line = order.order_lines.first

          expect(line.product).to eq product
        end
      end

      context "with exploaded prepacks and variants" do
        subject { FakeExploadedVariantPrepack850Parser.new }

        it "parses an 850 that has prepack lines and variants" do
          subject.process_transaction(user, transaction, last_file_bucket: "bucket", last_file_path: "path")

          # It should have created an importer
          importer = Company.where(importer: true, system_code: "Test").first
          expect(importer).not_to be_nil

          product = Product.where(importer_id: importer.id, unique_identifier: "Test-14734003").first
          expect(product).not_to be_nil
          # Because we're not exploading prepacks, the prepack specific parser method shouldn't be utilized
          expect(product.name).to eq "PREPACK"
          # It should snapshot the product because be default we tell it the product was updated
          expect(product.entity_snapshots.length).to eq 1
          expect(product.entity_snapshots.first.user).to eq user
          expect(product.entity_snapshots.first.context).to eq "path"

          expect(product.variants.length).to eq 2
          first_variant = product.variants.find {|v| v.variant_identifier == "123456"}
          expect(first_variant).not_to be_nil
          second_variant = product.variants.find {|v| v.variant_identifier == "987654"}
          expect(second_variant).not_to be_nil

          order = Order.where(importer_id: importer.id).first
          expect(order.order_number).to eq "Test-364225101"
          expect(order.customer_order_number).to eq "364225101"
          expect(order.season).to eq "TEST"
          expect(order.last_file_bucket).to eq "bucket"
          expect(order.last_file_path).to eq "path"
          expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201607250954"

          expect(order.entity_snapshots.length).to eq 1
          expect(order.entity_snapshots.first.user).to eq user
          expect(order.entity_snapshots.first.context).to eq "path"

          expect(order.order_lines.length).to eq 2
          line = order.order_lines.first

          expect(line.product).to eq product
          expect(line.variant).to eq first_variant

          line = order.order_lines.second
          expect(line.product).to eq product
          expect(line.variant).to eq second_variant
        end
      end
    end
  end

  describe "find_or_create_company_from_n1_data" do
    subject { FakeStandard850Parser.new }
    let (:transaction) { REX12.each_transaction(StringIO.new(standard_transaction_data)).first }
    let (:n1_loop) { subject.extract_n1_loops(transaction.segments, qualifier: "ST").first }
    let (:n1_data) { subject.extract_n1_entity_data n1_loop }
    let! (:us) { Factory(:country, iso_code: "US") }
    let (:importer) { Company.where(importer: true, system_code: "Test").first }

    it "extracts data from an n1 segment into a hash" do
      # This test exists due to the way we're overriding this method and proxyig calls to the super 
      # implementation of this method...just want to make sure it stays working and consistent
      expect(Lock).to receive(:acquire).with("Company-Test-0080", yield_in_transaction: false).and_yield

      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}
      expect(company.persisted?).to eq true
      expect(importer.linked_companies).to include company
      expect(company.system_code).to eq "Test-0080"
      expect(company.factory).to eq true
      expect(company.name).to eq "The Talbots Inc"
      expect(company.name_2).to eq "TALBOTS IMPORT,LLC FOR THE ACCOUNT OF,THE TALBOTS INC"
      expect(company.addresses.length).to eq 1
      address = company.addresses.first
      expect(address.line_1).to eq "1 TALBOTS WAY"
      expect(address.line_2).to eq "SUITE 200"
      expect(address.city).to eq "LAKEVILLE"
      expect(address.state).to eq "MA"
      expect(address.postal_code).to eq "02348"
      expect(address.country).to eq us
    end
  end
end