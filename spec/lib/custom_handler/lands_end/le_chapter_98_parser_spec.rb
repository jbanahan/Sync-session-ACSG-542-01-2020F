require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'

describe OpenChain::CustomHandler::LandsEnd::LeChapter98Parser do
  subject { OpenChain::CustomHandler::LandsEnd::LeChapter98Parser.new(nil) }
  let(:entry) { generate_default_entry }

  def default_values
    HashWithIndifferentAccess.new({
        :client_num=>'LANDSEND-C',
        :client_name=>"LANDS' END",
        :export_control=>'20712',
        :export_date=>'',
        :reference=>'ONWSR0073355',
        :ticket=>'LEC-171229-1',
        :order=>'95403991-03',
        :returned_by=>'VANESSA',
        :address=>'1234 Main Street',
        :city=>'Some City',
        :province=>'NL',
        :postal_code=>'A0K 3PO',
        :part_style=>'4758620',
        :subdiv=>'487168',
        :factory_code=>'',
        :description_1=>'Something here',
        :description_2=>'Something Else',
        :cdn_hs=>'6202.93.00.20',
        :us_hs=>'',
        :country_origin=>'BD',
        :pcs=>'1',
        :value=>'131.4',
        :total=>'131.4',
        :date_imported=>'11/7/2017',
        :transaction=>'15818-02595020',
        :b3_date=>'12/31/2017',
        :office_imported=>"453",
        :duty_import=>'30.19',
        :gst_import=>'0',
        :hst_pst=>'29.69',
        :excise_tax=>'0',
        :days_in=>''
    })
  end

  def make_row overrides={}
    h = default_values.merge overrides
    [:client_num, :client_name, :export_control, :export_date,
     :reference, :ticket, :order, :returned_by, :address, :city,
     :province, :postal_code, :part_style, :subdiv, :factory_code, :description_1,
     :description_2, :cdn_hs, :us_hs, :country_origin, :pcs, :value, :total,
     :date_imported, :transaction, :b3_date, :office_imported, :duty_import,
     :gst_import, :hst_pst, :excise_tax, :days_in].collect { |k| h[k] }
  end

  def make_csv_file rows
    @temp = Tempfile.new "LeCSV"
    csv = CSV.new @temp
    rows.each { |r| csv << r }
    @temp.rewind
    @temp
  end

  def generate_default_invoice_line
    line = OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport::CiLoadInvoiceLine.new
    line.part_number = default_values[:part_style]
    line.country_of_origin = default_values[:country_origin]
    line.pieces = default_values[:pcs].to_d
    line.hts = '9801001098'
    line.foreign_value = default_values[:value].to_d
    line.mid = 'XORUSFAR6220LAS'
    line
  end

  def generate_default_invoice
    invoice = OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport::CiLoadInvoice.new
    invoice.invoice_number = default_values[:export_control]
    invoice.invoice_date = Time.zone.now
    invoice.invoice_lines = [generate_default_invoice_line]
    invoice
  end

  def generate_default_entry
    e = OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport::CiLoadEntry.new
    e.file_number = '1234567890'
    e.customer = 'LANDS1'
    e.invoices = [generate_default_invoice]
    e
  end

  describe 'generate_invoice_line' do
    it 'generates an invoice line given a rolled up hash' do
      csv = []
      csv << make_row
      roll_up_hash = subject.generate_initial_hash(csv)
      subject.sum_roll_up(roll_up_hash, csv)
      expected = generate_default_invoice_line
      result = subject.generate_invoice_line(roll_up_hash)
      expect(expected).to eql(result)
    end
  end

  describe 'generate_invoice' do
    it 'generates an invoice when given invoice_lines' do
      Timecop.freeze(Time.zone.now) do
        csv = []
        csv << make_row
        roll_up_hash = subject.generate_initial_hash(csv)
        subject.sum_roll_up(roll_up_hash, csv)
        lines = []
        lines << subject.generate_invoice_line(roll_up_hash)
        expected = generate_default_invoice
        result = subject.generate_invoice(default_values[:export_control], Time.zone.now, lines)
        expect(expected).to eql(result)
      end
    end
  end

  describe 'sort_csv' do
    it 'handles a single entry' do
      csv = []
      csv << make_row
      sorted_csv = subject.sort_csv(csv)
      expect(sorted_csv[0][0][19]).to eql 'BD'
    end

    it 'properly sorts ascending' do
      csv = []
      csv << make_row({'country_origin' => 'ZA'})
      csv << make_row
      sorted_csv = subject.sort_csv(csv)
      expect(sorted_csv[0][0][19]).to eql 'BD'
      expect(sorted_csv[1][0][19]).to eql 'ZA'
    end

    it 'properly sorts when given multiple lines per origin' do
      csv = []
      csv << make_row({'country_origin' => 'ZA'})
      csv << make_row({'country_origin' => 'ZA'})
      csv << make_row({'country_origin' => 'BC'})
      csv << make_row({'country_origin' => 'BD'})

      sorted_csv = subject.sort_csv(csv)
      expect(sorted_csv[0][0][19]).to eql 'BC'
      expect(sorted_csv[1][0][19]).to eql 'BD'
      expect(sorted_csv[2][0][19]).to eql 'ZA'
      expect(sorted_csv[2][1][19]).to eql 'ZA'
    end
  end

  describe 'sum_roll_up' do
    it 'sums up the value field properly' do
      csv = []
      csv << make_row({'country_origin' => 'ZA'})
      csv << make_row({'country_origin' => 'ZA'})
      roll_up_hash = subject.generate_initial_hash(csv)
      subject.sum_roll_up(roll_up_hash, csv)
      expect(roll_up_hash['value']).to eql(131.4*2)
    end

    it 'sums up the pcs field properly' do
      csv = []
      csv << make_row({'country_origin' => 'ZA'})
      csv << make_row({'country_origin' => 'ZA'})
      roll_up_hash = subject.generate_initial_hash(csv)
      subject.sum_roll_up(roll_up_hash, csv)
      expect(roll_up_hash['pcs']).to eql(2)
    end
  end

  describe 'generate_entry' do
    it 'generates an entry given invoices' do
      Timecop.freeze(Time.zone.now) do
        generated_entry = subject.generate_entry([generate_default_invoice], '1234567890')
        expect(generated_entry).to eql entry
      end
    end
  end

  describe "can_view?" do
    it "allows company master to view when WWW custom feature is enabled" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      expect(ms).to receive(:custom_feature?).with('WWW VFI Track Reports').and_return true

      u = FactoryBot(:master_user)
      expect(described_class.new(nil).can_view? u).to be_truthy
    end

    it "prevents non-master user" do
      u = FactoryBot(:user)
      expect(described_class.new(nil).can_view? u).to be_falsey
    end

    it "prevents non-WWW user" do
      ms = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return ms
      expect(ms).to receive(:custom_feature?).with('WWW VFI Track Reports').and_return false

      u = FactoryBot(:master_user)
      expect(described_class.new(nil).can_view? u).to be_falsey
    end
  end
end
