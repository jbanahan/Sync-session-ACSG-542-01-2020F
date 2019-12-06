describe OpenChain::CustomHandler::Burlington::BurlingtonProductParser do
  let(:user) do
    u = Factory(:master_user)
    allow(u).to receive(:edit_products?).and_return true
    u
  end

  let(:cf) do
    file = instance_double("CustomFile")
    allow(file).to receive(:attached_file_name).and_return("filename.xlsx")
    file
  end

  describe "can_view?" do
    let(:ms) { stub_master_setup }

    before do
      allow(ms).to receive(:custom_feature?).with("Burlington Parts").and_return(true)
      cf
    end

    it "allows master user with edit permission when custom feature is present" do
      expect(described_class.can_view?(user)).to eq(true)
    end

    it "blocks non-master user" do
      user.company.update!(master: false)
      user.reload
      expect(described_class.can_view?(user)).to eq(false)
    end

    it "blocks user without edit permission" do
      allow(user).to receive(:edit_products?).and_return(false)
      expect(described_class.can_view?(user)).to eq(false)
    end

    it "returns 'false' if custom feature isn't present" do
      allow(ms).to receive(:custom_feature?).with("Burlington Parts").and_return(false)
      expect(described_class.can_view?(user)).to eq(false)
    end
  end

  describe "process" do
    let(:user) { Factory(:user) }

    subject { described_class.new(cf) }

    it "assigns completion message" do
      expect(subject).to receive(:process_file).with(cf, user)
      subject.process(user)
      expect(user.messages.length).to eq(1)
      m = user.messages.first
      expect(m.subject).to eq("File Processing Complete")
      expect(m.body).to eq("Burlington Product Upload processing for file filename.xlsx is complete.")
    end

    it "assigns error message" do
      expect(subject).to receive(:process_file).with(cf, user).and_raise("ERROR!!")
      subject.process(user)
      expect(user.messages.length).to eq(1)
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Unable to process file filename.xlsx due to the following error:<br>ERROR!!"
    end
  end

  describe "process_file" do
    let(:header1) { ["Category:", "Apparel - Coats", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""] }
    let(:header2) { ["PICTURE", "FACTORY (IF MORE THAN 1)", "Brand or Label (If Any)", "Vendor Style", "Vendor Color", "Description", "First Cost", "Components", "Materal Breakdown", "HTS#", "Duty Rate", "Size Break", "Total Qty", "Qty In", "UPC", "Prepack UPC", "UPC Catalog Style", "UPC Catalog Color", "NRF Color Code", "Carton Dimensions", "", "", "Inces or CMs", "Carton Weight KG", "Shipping on Pallets", "", "Audit Checklist", "Are the Coats", "Are they knit", "Are Waterproof", "Complete Recreational"] }
    let(:header3) { ["Required", "", "", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "", "If Applicable", "Required", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "W", "L", "H", "", "", "Select", "", "Import Dept", "", "", "", "", ""] }
    let(:row1) { ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-B", "SILVER", "Frozen 2 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""] }
    let(:row2) { ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-B", "SILVER", "Frozen 2 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""] }
    let(:row3) { ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-C", "SILVER", "Frozen 3 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""] }
    let(:row4) { ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-C", "SILVER", "Frozen 3 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""] }
    let(:us) { Factory(:country, iso_code: "US") }
    let(:imp) { Factory(:company, system_code: "BURLI")}
    subject { described_class.new(cf) }
    let(:cdefs) { subject.cdefs }
    before { us; cf; imp }

    it "sets classification notes" do
      header1 = ["Category:", "Apparel - Coats", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
      header2 = ["PICTURE", "FACTORY (IF MORE THAN 1)", "Brand or Label (If Any)", "Vendor Style", "Vendor Color", "Description", "First Cost", "Components", "Materal Breakdown", "HTS#", "Duty Rate", "Size Break", "Total Qty", "Qty In", "UPC", "Prepack UPC", "UPC Catalog Style", "UPC Catalog Color", "NRF Color Code", "Carton Dimensions", "", "", "Inces or CMs", "Carton Weight KG", "Shipping on Pallets", "", "Audit Checklist", "Are the Coats", "Are they knit", "Are Waterproof", "Complete Recreational"]
      header3 = ["Required", "", "", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "", "If Applicable", "Required", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "W", "L", "H", "", "", "Select", "", "Import Dept", "", "", "", "", ""]
      row1 = ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-B", "SILVER", "Frozen 2 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""]

      expect(subject).to receive(:foreach).with(cf, skip_headers: false).and_yield(header1).and_yield(header2).and_yield(header3).and_yield(row1)
      expect { subject.process_file(cf, user) }.to change(Product, :count).from(0).to(1)
      p1 = Product.first

      cl = p1.classifications.first
      expect(cl.country).to eq us
      expect(cl.custom_value(cdefs[:class_classification_notes])).to eq "Are they knit - OUTSOLE:100% eva"
    end

    it "handles blank rows when parsing" do
      header1 = ["Category:", "Apparel - Coats", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
      header2 = ["PICTURE", "FACTORY (IF MORE THAN 1)", "Brand or Label (If Any)", "Vendor Style", "Vendor Color", "Description", "First Cost", "Components", "Materal Breakdown", "HTS#", "Duty Rate", "Size Break", "Total Qty", "Qty In", "UPC", "Prepack UPC", "UPC Catalog Style", "UPC Catalog Color", "NRF Color Code", "Carton Dimensions", "", "", "Inces or CMs", "Carton Weight KG", "Shipping on Pallets", "", "Audit Checklist", "Are the Coats", "Are they knit", "Are Waterproof", "Complete Recreational"]
      header3 = ["Required", "", "", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "", "If Applicable", "Required", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "W", "L", "H", "", "", "Select", "", "Import Dept", "", "", "", "", ""]
      row1 = ["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]

      expect(subject).to receive(:foreach).with(cf, skip_headers: false).and_yield(header1).and_yield(header2).and_yield(header3).and_yield(row1)
      expect { subject.process_file(cf, user) }.to_not change(Product, :count)
    end

    it "parses products" do
      expect(subject).to receive(:foreach).with(cf, skip_headers: false).and_yield(header1).and_yield(header2).and_yield(header3).and_yield(row1).and_yield(row2).and_yield(row3).and_yield(row4)
      expect { subject.process_file(cf, user) }.to change(Product, :count).from(0).to(2)
      p1, p2 = Product.all

      expect(p1.unique_identifier).to eq("NIFR7750A-B")
      expect(p1.name).to eq("Frozen 2 sandal")
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq("NIFR7750A-B")
      expect(p1.custom_value(cdefs[:prod_short_description])).to eq("pu+ eva outsole")
      expect(p1.custom_value(cdefs[:prod_long_description])).to eq("UPPER:95% plastic +5% copper OUTSOLE:100% eva")
      expect(p1.custom_value(cdefs[:prod_type])).to eq("Apparel - Coats")
      expect(p1.classifications.length).to eq(1)
      cl = p1.classifications.first
      expect(cl.country).to eq(us)
      expect(cl.tariff_records.length).to eq(1)
      expect(cl.tariff_records.first.hts_1).to eq("6402992590")
      expect(p1.entity_snapshots.length).to eq(1)
      es = p1.entity_snapshots.first
      expect(es.user).to eq(user)
      expect(es.context).to eq("BurlingtonProductParser")

      expect(p2.unique_identifier).to eq("NIFR7750A-C")
      expect(p2.name).to eq("Frozen 3 sandal")
      expect(p2.custom_value(cdefs[:prod_short_description])).to eq("pu+ eva outsole")
      expect(p2.custom_value(cdefs[:prod_long_description])).to eq("UPPER:95% plastic +5% copper OUTSOLE:100% eva")
      expect(p2.classifications.length).to eq(1)
      cl = p2.classifications.first
      expect(cl.country).to eq(us)
      expect(cl.tariff_records.length).to eq(1)
      expect(cl.tariff_records.first.hts_1).to eq("6402992590")
      expect(p2.entity_snapshots.length).to eq(1)
      es = p2.entity_snapshots.first
      expect(es.user).to eq(user)
      expect(es.context).to eq("BurlingtonProductParser")
    end

    it "updates products" do
      expect(subject).to receive(:foreach).with(cf, skip_headers: false).and_yield(header2).and_yield(header3).and_yield(row1).and_yield(row2).and_yield(row3).and_yield(row4)
      expect { subject.process_file(cf, user) }.to change(Product, :count).from(0).to(2)
      p1, p2 = Product.all

      header1 = ["Category:", "Apparel - Coats", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
      header2 = ["PICTURE", "FACTORY (IF MORE THAN 1)", "Brand or Label (If Any)", "Vendor Style", "Vendor Color", "Description", "First Cost", "Components", "Materal Breakdown", "HTS#", "Duty Rate", "Size Break", "Total Qty", "Qty In", "UPC", "Prepack UPC", "UPC Catalog Style", "UPC Catalog Color", "NRF Color Code", "Carton Dimensions", "", "", "Inces or CMs", "Carton Weight KG", "Shipping on Pallets", "", "Audit Checklist", "Are the Coats", "Are they knit", "Are Waterproof", "Complete Recreational"]
      header3 = ["Required", "", "", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "Required", "", "If Applicable", "Required", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "Only if Req", "W", "L", "H", "", "", "Select", "", "Import Dept", "", "", "", "", ""]
      row1 = ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-B", "SILVER", "Hot 2 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""]
      row2 = ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-B", "SILVER", "Hot 2 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""]
      row3 = ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-C", "SILVER", "Hot 3 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""]
      row4 = ["", "PuTian YongFeng Footwear Co.,Ltd", "Frozen2", "NIFR7750A-C", "SILVER", "Hot 3 sandal", "$5.80", "pu+ eva outsole", "UPPER:95% plastic +5% copper OUTSOLE:100% eva", "6402.99.2590", "12.5%", "6-10#", "", "", "6", "", "", "", "", "", "34.0", "26.0", "Inches (Standard)", "2", "", "", "", "UPPER: 95% plastic +5% copper", "OUTSOLE:100% eva", "", "", ""]

      expect(subject).to receive(:foreach).with(cf, skip_headers: false).and_yield(header1).and_yield(header2).and_yield(header3).and_yield(row1).and_yield(row2).and_yield(row3).and_yield(row4)
      expect { subject.process_file(cf, user) }.to_not change(Product, :count)
      p1.reload; p2.reload

      expect(p1.unique_identifier).to eq("NIFR7750A-B")
      expect(p1.name).to eq("Hot 2 sandal")
      expect(p1.custom_value(cdefs[:prod_short_description])).to eq("pu+ eva outsole")
      expect(p1.custom_value(cdefs[:prod_long_description])).to eq("UPPER:95% plastic +5% copper OUTSOLE:100% eva")
      expect(p1.classifications.length).to eq(1)
      cl = p1.classifications.first
      expect(cl.country).to eq(us)
      expect(cl.tariff_records.length).to eq(1)
      expect(cl.tariff_records.first.hts_1).to eq("6402992590")
      expect(p1.entity_snapshots.length).to eq(2)

      expect(p2.unique_identifier).to eq("NIFR7750A-C")
      expect(p2.name).to eq("Hot 3 sandal")
      expect(p2.custom_value(cdefs[:prod_short_description])).to eq("pu+ eva outsole")
      expect(p2.custom_value(cdefs[:prod_long_description])).to eq("UPPER:95% plastic +5% copper OUTSOLE:100% eva")
      expect(p2.classifications.length).to eq(1)
      cl = p2.classifications.first
      expect(cl.country).to eq(us)
      expect(cl.tariff_records.length).to eq(1)
      expect(cl.tariff_records.first.hts_1).to eq("6402992590")
      expect(p2.entity_snapshots.length).to eq(2)
    end
  end
end