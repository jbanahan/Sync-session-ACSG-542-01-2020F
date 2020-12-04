describe OpenChain::CustomHandler::Target::TargetDocumentPacketXmlGenerator do

  let (:entry) do
    e = Entry.new entry_number: "316123456", import_date: Date.new(2020, 5, 1)
    i = e.commercial_invoices.build invoice_number: "BOL"
    i.commercial_invoice_lines.build po_number: "12345", department: "123"
    i.commercial_invoice_lines.build po_number: "12345", department: "123"
    i.commercial_invoice_lines.build po_number: "", department: "" # Ensure that these are skipped
    i.commercial_invoice_lines.build po_number: "54321", department: "123"

    e
  end

  let (:attachment) do
    Attachment.new attachment_type: "Type 1", attached_file_name: "file.pdf"
  end

  let (:attachment2) do
    Attachment.new attachment_type: "Type 2", attached_file_name: "file2.pdf"
  end

  describe "generate_xml" do
    it "generates xml" do
      doc = subject.generate_xml entry, "BOL", [attachment, attachment2]
      root = doc.root
      expect(root.name).to eq "packet"
      expect(root).to have_xpath_value("source_name", "MaerskBroker")
      expect(root).to have_xpath_value("vendor_number", "5003461")
      expect(root).to have_xpath_value("bill_of_lading", "BOL")
      expect(root).to have_xpath_value("entry_id", "316-12345-6")
      expect(root).to have_xpath_value("eta", "2020-05-01")
      expect(root).to have_xpath_value("count(purchase_orders/po)", 2)
      expect(root).to have_xpath_value("purchase_orders/po[1]/@id", "123-12345")
      expect(root).to have_xpath_value("purchase_orders/po[2]/@id", "123-54321")
      expect(root).to have_xpath_value("image_count", "2")
      expect(root).to have_xpath_value("count(document_names/document)", 2)
      expect(root).to have_xpath_value("document_names/document[1]", "Type 1")
      expect(root).to have_xpath_value("document_names/document[1]/@id", "file.pdf")
      expect(root).to have_xpath_value("document_names/document[2]", "Type 2")
      expect(root).to have_xpath_value("document_names/document[2]/@id", "file2.pdf")
    end
  end
end
