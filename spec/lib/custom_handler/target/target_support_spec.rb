describe OpenChain::CustomHandler::Target::TargetSupport do
  let (:subject) { Class.new {extend OpenChain::CustomHandler::Target::TargetSupport} }

  describe "build_part_number" do
    it "combines DPCI and vendor order point to form part number" do
      expect(subject.build_part_number("AB", "CD")).to eq "AB-CD"
    end
  end

  describe "split_part_number" do
    it "splits part number into component DPCI and vendor order point" do
      expect(subject.split_part_number("12345-666")).to eq ["12345", "666"]
    end

    it "interprets only the final hyphen as the separator between DPCI and vendor order point" do
      expect(subject.split_part_number("12345-666-777")).to eq ["12345-666", "777"]
    end

    it "returns unmodified part number and nil if the part number contains no hyphen" do
      expect(subject.split_part_number("12345")).to eq ["12345", nil]
    end

    it "raises an error if asked to split a nil value" do
      expect { subject.split_part_number(nil) }.to raise_error(NoMethodError)
    end
  end

  describe "order_number" do
    it "appends department to PO number when present" do
      inv_line = CommercialInvoiceLine.new(po_number: "ZYX556", department: "DPTX")
      expect(subject.order_number(inv_line)).to eq "DPTX-ZYX556"
    end

    it "returns PO number unmodified when department is blank" do
      inv_line = CommercialInvoiceLine.new(po_number: "ZYX556", department: " ")
      expect(subject.order_number(inv_line)).to eq "ZYX556"
    end

    it "returns PO number unmodified when department is nil" do
      inv_line = CommercialInvoiceLine.new(po_number: "ZYX556", department: nil)
      expect(subject.order_number(inv_line)).to eq "ZYX556"
    end

    it "raises an error if passed nil" do
      expect { subject.order_number(nil) }.to raise_error(NoMethodError)
    end
  end

end