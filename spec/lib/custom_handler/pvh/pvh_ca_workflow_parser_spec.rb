describe OpenChain::CustomHandler::Pvh::PvhCaWorkflowParser do
  let(:user) { create(:master_user) }
  let(:fenix) { OpenChain::CustomHandler::FenixNdInvoiceGenerator }

  describe "can_view?" do
    let(:parser) { described_class.new double("custom file")}

    it "allows master users on www" do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return 'www-vfitrack-net'

      expect(parser.can_view? user).to eq true
    end

    it "prevents access by non-master users on www" do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return 'www-vfitrack-net'
      user.company.update_attributes(master: false)

      expect(parser.can_view? user).to eq false
    end

    it "prevents access by master users on other instances" do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return 'pepsi'

      expect(parser.can_view? user).to eq false
    end
  end

  describe "process" do
    context "it delegates to FenixNdInvoiceGenerator" do
        #                                                            10          11              12                     15         16             19         21                 24     26               29       30          31
      let(:row_1)  { ["", "", "", "", "", "", "", "", "", "", "COO 1':|+?", "vend name 1", "invoice num 1", "", "", "po num 1", "style 1", "", "", 1, "", "HTS 111111", "", "", 2, "", 3, "", "", "note a1", "note b1", "note c1", "", "", "", "", "", "", "", ""] }
      let(:row_1a) { ["", "", "", "", "", "", "", "", "", "", "", "fact name 1", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""] }
      let(:row_2)  { ["", "", "", "", "", "", "", "", "", "", "COO 2",      "vend name 1", "invoice num 1", "", "", "po num 2", "style 2", "", "", 2, "", "HTS 222222", "", "", 3, "", 4, "", "", "note a2", "note b2", "note c2", "", "", "", "", "", "", "", ""] }
      let(:row_2a) { ["", "", "", "", "", "", "", "", "", "", "", "fact name 2", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""] }
      let(:row_3)  { ["", "", "", "", "", "", "", "", "", "", "COO 3",      "vend name 2", "invoice num 2", "", "", "po num 3", "style 3", "", "", 3, "", "HTS 333333", "", "", 4, "", 5, "", "", "note a3", "note b3", "note c3", "", "", "", "", "", "", "", ""] }
      let(:row_3a) { ["", "", "", "", "", "", "", "", "", "", "", "fact name 3", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""] }

      let!(:cf) { double "custom file" }

      let(:parser) do
        allow(cf).to receive(:path).and_return "path/to/upload.xls"
        allow(cf).to receive(:id).and_return 1
        described_class.new cf
      end

      let(:now) { Time.zone.now.in_time_zone("America/New_York") }

      it "sends new invoices, updates xref" do
        expect(parser).to receive(:foreach).with(cf).twice.and_yield([], 0).and_yield([], 1).and_yield([], 2)
                                                          .and_yield(row_1, 3).and_yield(row_1a, 4)
                                                          .and_yield(row_2, 5).and_yield(row_2a, 6)
                                                          .and_yield(row_3, 7).and_yield(row_3a, 8)

        expect(fenix).to receive(:generate) do |inv|
          expect(inv.persisted?).to eq false
          expect(inv.currency).to eq "USD"
          expect(inv.invoice_date).to eq(now.to_date)
          expect(inv.invoice_number).to eq "invoice num 1"
          expect(inv.total_quantity).to eq 7
          expect(inv.total_quantity_uom).to eq "CTN"
          expect(inv.commercial_invoice_lines.length).to eq 2
          ci_1, * = inv.commercial_invoice_lines
          expect(ci_1.part_number).to eq "style 1"
          expect(ci_1.country_origin_code).to eq "COO 1"
          expect(ci_1.quantity).to eq 1
          expect(ci_1.unit_price).to eq 2
          expect(ci_1.po_number).to eq "po num 1"
          expect(ci_1.commercial_invoice_tariffs.length).to eq 1
          cit = ci_1.commercial_invoice_tariffs.first
          expect(cit.hts_code).to eq "HTS 111111"
          expect(cit.tariff_description).to eq "note a1 note b1 note c1"
        end

        expect(fenix).to receive(:generate) do |inv|
          expect(inv.persisted?).to eq false
          expect(inv.currency).to eq "USD"
          expect(inv.invoice_date).to eq(now.to_date)
          expect(inv.invoice_number).to eq "invoice num 2"
          expect(inv.total_quantity).to eq 5
          expect(inv.total_quantity_uom).to eq "CTN"
          expect(inv.commercial_invoice_lines.length).to eq 1
          cil = inv.commercial_invoice_lines.first
          expect(cil.part_number).to eq "style 3"
          expect(cil.country_origin_code).to eq "COO 3"
          expect(cil.quantity).to eq 3
          expect(cil.unit_price).to eq 4
          expect(cil.po_number).to eq "po num 3"
          expect(cil.commercial_invoice_tariffs.length).to eq 1
          cit = cil.commercial_invoice_tariffs.first
          expect(cit.hts_code).to eq "HTS 333333"
          expect(cit.tariff_description).to eq "note a3 note b3 note c3"
        end

        Timecop.freeze(now) { parser.process user }

        expect(DataCrossReference.find_pvh_invoice("vend name 1", "invoice num 1")).to eq true
        expect(DataCrossReference.find_pvh_invoice("vend name 2", "invoice num 2")).to eq true
      end

      it "skips already-existing invoices" do
        DataCrossReference.create_pvh_invoice!("vend name 1", "invoice num 1")
        expect(parser).to receive(:foreach).with(cf).twice.and_yield([], 0).and_yield([], 1).and_yield([], 2)
                                                          .and_yield(row_1, 3).and_yield(row_1a, 4)
                                                          .and_yield(row_2, 5).and_yield(row_2a, 6)
        expect(fenix).not_to receive(:generate)
        parser.process user
      end

      it "leaves HTS blank if invoice line has multiple" do
        row_1[22] = "HTS 222222"
        expect(parser).to receive(:foreach).with(cf).twice.and_yield([], 0).and_yield([], 1).and_yield([], 2)
                                                          .and_yield([], 0).and_yield([], 1).and_yield([], 2)
                                                          .and_yield(row_1, 3).and_yield(row_1a, 4)
                                                          .and_yield(row_2, 5).and_yield(row_2a, 6)
        expect(fenix).to receive(:generate) do |inv|
          expect(inv.commercial_invoice_lines.length).to eq 2
          ci_1, * = inv.commercial_invoice_lines
          expect(ci_1.commercial_invoice_tariffs.length).to eq 1
          cit = ci_1.commercial_invoice_tariffs.first
          expect(cit.hts_code).to be_nil
          expect(cit.tariff_description).to eq "note a1 note b1 note c1"
        end

        parser.process user
      end

      it "raises exception for file-type other than xls, xlsx" do
        allow(cf).to receive(:path).and_return "path/to/upload.csv"
        parser = described_class.new cf
        expect { parser.process user }.to raise_error ArgumentError, "Only XLS and XLSX files are accepted."
      end

    end
  end

end