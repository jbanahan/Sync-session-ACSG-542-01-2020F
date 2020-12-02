describe OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser do
  describe "process_attachment" do
    it "should get path and call parse" do
      u = double(:user)
      s = double(:shipment)
      att = double(:attachment)
      atchd = double(:attached)
      expect(att).to receive(:attached).and_return atchd
      path = 'xyz'
      expect(atchd).to receive(:path).and_return path
      expect(described_class).to receive(:parse).with(s, path, u, nil, nil).and_return 'x'
      expect(described_class.process_attachment(s, att, u)).to eq 'x'
    end
  end
  describe "parse" do
    it "should create object and call run" do
      s = double('shipment')
      path = double('data')
      x = double('xlclient')
      u = double('user')
      expect(OpenChain::XLClient).to receive(:new).with(path).and_return x
      t = double('x')
      expect(described_class).to receive(:new).and_return t
      expect(t).to receive(:run).with(s, x, u, nil, nil)
      described_class.parse s, path, u
    end
  end

  describe "run" do
    it "should process_rows" do
      x = double('xlclient')
      s = double('shipment')
      u = double('user')
      r = double('rows')
      expect(x).to receive(:all_row_values).and_return r
      d = described_class.new
      expect(d).to receive(:process_rows).with(s, r, u, nil, nil)
      d.run(s, x, u)
    end
  end
  describe "process_rows" do
    def init_mock_array total_rows, row_values_hash
      r = Array.new(total_rows, [])
      # always set cell B2 to 'Packing Manifest'
      r[1] = ['', 'Packing Manifest']
      row_values_hash.each do |k, v|
        r[k] = v
      end
      r
    end
    def mode_row mode
      ['', '', '', '', 'Method', '', '', '', '', '', '', mode]
    end
    def subtitle_row subtitle
      ['', subtitle]
    end
    def detail_line overrides
      base = {range:'0001',
        carton_start:'1234500',
        carton_end:'1234502',
        po:'ORD',
        sku:'SK',
        item_qty:'60',
        carton_qty:'3',
        net_net:'6.600',
        net:'6.800',
        gross:'7.000',
        weight_unit:'KG',
        length:'10.000',
        width:'100.000',
        height:'1000.000',
        dim_unit:'CM'
      }.merge overrides
      r = Array.new(57, '')
      r[5] = base[:range]
      r[6] = base[:carton_start]
      r[9] = base[:carton_end]
      r[14] = base[:po]
      r[20] = base[:sku]
      r[29] = base[:item_qty]
      r[37] = base[:carton_qty]
      r[42] = base[:net_net]
      r[45] = base[:net]
      r[47] = base[:gross]
      r[48] = base[:weight_unit]
      r[49] = base[:length]
      r[51] = base[:width]
      r[53] = base[:height]
      r[55] = base[:dim_unit]
      r
    end

    before :each do
      @s = create(:shipment)
      @u = create(:user)
      allow(@s).to receive(:can_edit?).and_return true
    end
    it "should error if cell B2 doesn't say 'Packing Manifest'" do
      r = init_mock_array 3, {1=>['', '']}
      expect {described_class.new.process_rows(@s, r, @u)}.to raise_error "INVALID FORMAT: Cell B2 must contain 'Packing Manifest'."
    end
    it "should error if user cannot edit shipment" do
      allow(@s).to receive(:can_edit?).and_return false
      expect {described_class.new.process_rows(@s, init_mock_array(3, {}), @u)}.to raise_error "You do not have permission to edit this shipment."
    end
    it "adds containers for ocean, and add 40 ft dry van container information" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        81=>subtitle_row('Package Detail'),
        83=>[nil, nil, nil, 'Equipment #: ABCD12345 Type: Standard Dry 40 foot Seal #: SEAL1234']
      }
      rows = init_mock_array 85, row_seed
      expect_any_instance_of(described_class).to receive(:review_orders).with @u, @s, nil
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(Container, :count).from(0).to(1)
      @s.reload
      cont = @s.containers.first
      expect(cont.container_number).to eq 'ABCD12345'
      expect(cont.container_size).to eq "40DV"
      expect(cont.seal_number).to eq "SEAL1234"
    end
    it "adds containers for ocean, and add High cube 40 ft container information" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        81=>subtitle_row('Package Detail'),
        83=>[nil, nil, nil, 'Equipment #: ABCD12345 Type: High Cube 40 ft. Seal #: SEAL1234']
      }
      rows = init_mock_array 85, row_seed
      expect_any_instance_of(described_class).to receive(:review_orders).with @u, @s, nil
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(Container, :count).from(0).to(1)
      @s.reload
      cont = @s.containers.first
      expect(cont.container_number).to eq 'ABCD12345'
      expect(cont.container_size).to eq "40HQ"
      expect(cont.seal_number).to eq "SEAL1234"
    end
    it "adds containers for ocean, and add 20 ft dry container information (skipping null seal)" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        81=>subtitle_row('Package Detail'),
        83=>[nil, nil, nil, 'Equipment #: ABCD12345 Type: Standard Dry 20 ft Seal #: null']
      }
      rows = init_mock_array 85, row_seed
      expect_any_instance_of(described_class).to receive(:review_orders).with @u, @s, nil
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(Container, :count).from(0).to(1)
      @s.reload
      cont = @s.containers.first
      expect(cont.container_number).to eq 'ABCD12345'
      expect(cont.container_size).to eq "20DV"
      expect(cont.seal_number).to be_nil
    end

    it "adds containers for ocean, and add High cube 40 ft container information" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        81=>subtitle_row('Package Detail'),
        83=>[nil, nil, nil, 'Equipment #: ABCD12345 Type: High Cube 45 foot. Seal #: SEAL1234']
      }
      rows = init_mock_array 85, row_seed
      expect_any_instance_of(described_class).to receive(:review_orders).with @u, @s, nil
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(Container, :count).from(0).to(1)
      @s.reload
      cont = @s.containers.first
      expect(cont.container_number).to eq 'ABCD12345'
      expect(cont.container_size).to eq "45HQ"
      expect(cont.seal_number).to eq "SEAL1234"
    end

    it "ignores blank container summary information" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        81=>subtitle_row('Package Detail'),
        83=>[nil, nil, nil, 'Equipment #: ABCD12345 Type: Seal #: ']
      }
      rows = init_mock_array 85, row_seed
      expect_any_instance_of(described_class).to receive(:review_orders).with @u, @s, nil
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(Container, :count).from(0).to(1)
      @s.reload
      cont = @s.containers.first
      expect(cont.container_number).to eq 'ABCD12345'
      expect(cont.container_size).to be_nil
      expect(cont.seal_number).to be_nil
    end

    it "should not duplicate containers" do
      @s.containers.create!(container_number:'ABCD12345')
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals']
      }
      rows = init_mock_array 80, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to_not change(Container, :count)
    end
    it "should ignore equipment for non-ocean" do
      row_seed = {61=>mode_row('AIR'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals']
      }
      rows = init_mock_array 80, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to_not change(Container, :count)
    end
    it "should add lines" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      ol2 = create(:order_line, quantity:100, product:p, sku:'sk55555', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
        87=>detail_line({po:'ordnum', sku:'sk55555', item_qty:'5'})
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(ShipmentLine, :count).from(0).to(2)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8
      expect(f.order_lines.to_a).to eq [ol]
      expect(f.line_number).to eq 1
      l = @s.shipment_lines.last
      expect(l.product).to eq p
      expect(l.quantity).to eq 5
      expect(l.order_lines.to_a).to eq [ol2]
      expect(l.line_number).to eq 2
    end

    it "should add lines even if order# / sku is a numeric value" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'123', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'12345', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:123.0, sku:12345, item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(ShipmentLine, :count).from(0).to(1)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8
      expect(f.order_lines.to_a).to eq [ol]
      expect(f.line_number).to eq 1
    end

    it "should add lines when PACKAGE DETAIL header is used" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      ol2 = create(:order_line, quantity:100, product:p, sku:'sk55555', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('PACKAGE DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
        87=>detail_line({po:'ordnum', sku:'sk55555', item_qty:'5'})
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(ShipmentLine, :count).from(0).to(2)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8
      expect(f.order_lines.to_a).to eq [ol]
      expect(f.line_number).to eq 1
      l = @s.shipment_lines.last
      expect(l.product).to eq p
      expect(l.quantity).to eq 5
      expect(l.order_lines.to_a).to eq [ol2]
      expect(l.line_number).to eq 2
    end
    it "should handle commas in quantity" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8,000'}),
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to change(ShipmentLine, :count).from(0).to(1)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8000
      expect(f.order_lines.to_a).to eq [ol]
    end
    it "should not add lines for a different importer" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      @s.update_attributes(importer_id:create(:company).id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to raise_error "Order Number ordnum not found."
    end
    it "should assign lines to container" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        79=>['', '', '', 'Totals'],
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: ABCD12345 Type:123 Seal: DEF'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      described_class.new.process_rows(@s, rows, @u)
      @s.reload
      expect(@s.shipment_lines.first.container.container_number).to eq 'ABCD12345'
    end
    it "should handle blank line between EQUIPMENT SUMMARY and container table" do
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', ''],
        78=>['', '', '', 'Equipment #', 'Item Qty'],
        79=>['', '', '', 'ABCD12345', '1234', '10', ''], # only care about the container number
        80=>['', '', '', 'Totals'],
        83=>subtitle_row('CARTON DETAIL'),
        85=>['', '', '', 'Equipment#: ABCD12345 Type:123 Seal: DEF'],
        86=>['', '', '', '', 'Range'],
        87=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      described_class.new.process_rows(@s, rows, @u)
      @s.reload
      expect(@s.shipment_lines.first.container.container_number).to eq 'ABCD12345'

    end
    it "should fail on missing PO" do
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to raise_error "Order Number ordnum not found."
    end
    it "should fail on missing SKU" do
      c = create(:company)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to raise_error "SKU sk12345 not found in order ordnum (ID: #{o.id})."
    end
    it "raises error when order/manifest check fails if enable_warnings is present" do
      @s.update_attributes! reference: "REF1"
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'custordnum', order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      sl = create(:shipment_line, shipment: create(:shipment, reference: "REF2"), product: p)
      PieceSet.create! order_line: ol, shipment_line: sl, quantity: 1

      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'custordnum', sku:'sk12345', item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u, nil, true)}.to raise_error 'The following purchase orders are assigned to other shipments: custordnum (REF2)'
    end
    it "assigns warning_overridden attribs when enable_warnings is absent" do
      @s.update_attributes! reference: "REF1"
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'custordnum', order_number:'ordnum', approval_status: 'Accepted')
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      sl = create(:shipment_line, shipment: create(:shipment, reference: "REF2"), product: p)
      PieceSet.create! order_line: ol, shipment_line: sl, quantity: 1

      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'custordnum', sku:'sk12345', item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      Timecop.freeze(DateTime.new(2018, 1, 1)) { described_class.new.process_rows(@s, rows, @u, nil, false) }
      expect(@s.warning_overridden_by).to eq @u
      expect(@s.warning_overridden_at).to eq DateTime.new(2018, 1, 1)
    end
    it "errors if an order is 'unaccepted'" do
      @s.update_attributes! reference: "REF1"
      c = create(:company)
      p = create(:product)
      o = create(:order, importer:c, customer_order_number:'custordnum', order_number:'ordnum', approval_status: nil)
      ol = create(:order_line, quantity:100, product:p, sku:'sk12345', order:o)
      sl = create(:shipment_line, shipment: create(:shipment, reference: "REF2"), product: p)
      PieceSet.create! order_line: ol, shipment_line: sl, quantity: 1

      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'custordnum', sku:'sk12345', item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      expect { described_class.new.process_rows(@s, rows, @u, nil, false) }.to raise_error 'This file cannot be processed because the following orders are in an "unaccepted" state: custordnum'
    end
    it "should rollback changes on error" do
      c = create(:company)
      o = create(:order, importer:c, customer_order_number:'ordnum', approval_status: 'Accepted')
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['', '', '', 'Equipment #', 'Item Qty'],
        78=>['', '', '', 'ABCD12345', '1234', '10', ''],
        79=>['', '', '', 'Totals'],
        82=>subtitle_row('CARTON DETAIL'),
        84=>['', '', '', 'Equipment#: WHATEVER'],
        85=>['', '', '', '', 'Range'],
        86=>detail_line({po:'ordnum', sku:'sk12345', item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      expect {described_class.new.process_rows(@s, rows, @u)}.to raise_error(/SKU/)
      @s.reload
      expect(@s.containers).to be_empty
    end
    context "cartons" do
      before :each do
        c = create(:company)
        p = create(:product)
        o = create(:order, importer:c, customer_order_number:'ORD', approval_status: 'Accepted')
        ol = create(:order_line, quantity:100, product:p, sku:'SK', order:o)
        @s.update_attributes(importer_id:c.id)
      end
      it "should add carton ranges" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10'}),
          87=>detail_line({range:'0002', carton_start:'1102', carton_qty:'4', item_qty:'8'})
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(2)
        @s.reload
        cs = @s.carton_sets.find_by(starting_carton: '1100')
        expect(cs.carton_qty).to eq 2
        expect(cs.length_cm).to eq 10
        expect(cs.width_cm).to eq 100
        expect(cs.height_cm).to eq 1000
        expect(cs.net_net_kgs).to eq 6.6
        expect(cs.net_kgs).to eq 6.8
        expect(cs.gross_kgs).to eq 7
        expect(cs.shipment_lines.count).to eq 1
        expect(cs.shipment_lines.first).to eq @s.shipment_lines.first
        expect(@s.shipment_lines.count).to eq 2

        line = @s.shipment_lines.first
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 14
        expect(line.cbms).to eq 2

        line = @s.shipment_lines.second
        expect(line.carton_qty).to eq 4
        expect(line.gross_kgs).to eq 28
        expect(line.cbms).to eq 4

        expect(@s.gross_weight).to eq BigDecimal(42)
        expect(@s.number_of_packages).to eq 6
        expect(@s.number_of_packages_uom).to eq "CARTONS"
        expect(@s.volume).to eq BigDecimal(6)
      end
      it "adds shipment totals to existing amounts" do
        @s.gross_weight = BigDecimal(10)
        @s.volume = BigDecimal(10)
        @s.number_of_packages = 20
        @s.number_of_packages_uom = "CTNS"
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10'}),
          87=>detail_line({range:'0002', carton_start:'1102', carton_qty:'4', item_qty:'8'})
        }
        rows = init_mock_array 90, row_seed
        described_class.new.process_rows(@s, rows, @u)
        @s.reload

        expect(@s.gross_weight).to eq BigDecimal(52)
        expect(@s.number_of_packages).to eq 26
        expect(@s.number_of_packages_uom).to eq "CTNS"
        expect(@s.volume).to eq BigDecimal(16)
      end
      it "does not update number of packags unless package uom is CARTONS or CTNS" do
        @s.number_of_packages = 20
        @s.number_of_packages_uom = "Pieces"

        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10'}),
          87=>detail_line({range:'0002', carton_start:'1102', carton_qty:'4', item_qty:'8'})
        }
        rows = init_mock_array 90, row_seed
        described_class.new.process_rows(@s, rows, @u)
        @s.reload
        expect(@s.number_of_packages).to eq 20
      end
      it "should convert IN to CM" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10', dim_unit:'IN', length:'1', width:'1', height:'1'}),
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.length_cm).to eq 2.54
        expect(cs.width_cm).to eq 2.54
        expect(cs.height_cm).to eq 2.54
      end
      it "should convert Meters to CM" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10', dim_unit:'MR', length:'1', width:'1', height:'1'}),
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.length_cm).to eq 100
        expect(cs.width_cm).to eq 100
        expect(cs.height_cm).to eq 100
      end
      it "should convert Feet to CM" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10', dim_unit:'FT', length:'1', width:'1', height:'1'}),
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.length_cm).to eq 30.48
        expect(cs.width_cm).to eq 30.48
        expect(cs.height_cm).to eq 30.48
      end
      it "should convert LB to KG" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10', weight_unit:'LB', net:'2.20462'}),
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.net_kgs).to eq 1
      end
      it "should assign line w/ blank carton range to the last carton range and prorate values on shipment lines" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'2', item_qty:'10'}),
          87=>detail_line({range:'', carton_start:'', carton_qty:'', item_qty:'10'}),
          88=>detail_line({range:'0002', carton_start:'1102', carton_qty:'2', item_qty:'10'}),
        }
        rows = init_mock_array 90, row_seed
        expect {described_class.new.process_rows(@s, rows, @u)}.to change(CartonSet, :count).from(0).to(2)
        @s.reload
        expect(@s.shipment_lines.count).to eq 3
        cs_from_shipment_lines = @s.shipment_lines.collect {|sl| sl.carton_set}
        first_cs = @s.carton_sets.first
        last_cs = @s.carton_sets.last
        expect(cs_from_shipment_lines).to eq [first_cs, first_cs, last_cs]

        line = @s.shipment_lines.first
        expect(line.carton_qty).to eq 1
        expect(line.gross_kgs).to eq 7
        expect(line.cbms).to eq 1

        line = @s.shipment_lines.second
        expect(line.carton_qty).to eq 1
        expect(line.gross_kgs).to eq 7
        expect(line.cbms).to eq 1
      end

      it "handles carton prorations with complex remainders" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['', '', '', 'Equipment#: WHATEVER'],
          85=>['', '', '', '', 'Range'],
          86=>detail_line({range:'0001', carton_start:'1100', carton_qty:'10', item_qty:'10'}),
          87=>detail_line({range:'', carton_start:'', carton_qty:'', item_qty:'10'}),
          88=>detail_line({range:'', carton_start:'', carton_qty:'', item_qty:'10'}),
        }
        rows = init_mock_array 90, row_seed
        subject.process_rows(@s, rows, @u)
        @s.reload
        expect(@s.shipment_lines.length).to eq 3

        line = @s.shipment_lines.first
        expect(line.carton_qty).to eq 4
        expect(line.gross_kgs).to eq BigDecimal("23.34")
        expect(line.cbms).to eq BigDecimal("3.3334")

        line = @s.shipment_lines.second
        expect(line.carton_qty).to eq 3
        expect(line.gross_kgs).to eq BigDecimal("23.33")
        expect(line.cbms).to eq BigDecimal("3.3333")

        line = @s.shipment_lines[2]
        expect(line.carton_qty).to eq 3
        expect(line.gross_kgs).to eq BigDecimal("23.33")
        expect(line.cbms).to eq BigDecimal("3.3333")
      end

    end
  end
end
