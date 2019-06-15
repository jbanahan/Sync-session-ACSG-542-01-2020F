describe SnapshotDescriptor do

  let (:json) { '{"json": "WEEEEE!"}' }

  let (:writer) {
    writer = double("SnapshotWriter")
    allow(writer).to receive(:entity_json).and_return json
    writer
  }

  describe 'initialize' do

    it "accepts all params" do
      desc = described_class.new CommercialInvoice, parent_association: "commercial_invoices", writer: writer, children: [SnapshotDescriptor.new(CommercialInvoiceLine, parent_association: "commercial_invoice_lines")]
      expect(desc.entity_class).to eq CommercialInvoice
      expect(desc.parent_association).to eq "commercial_invoices"
      expect(desc.json_writer).to eq writer
      expect(desc.children.length).to eq 1
    end

    it "requires entity_class to be an active record object" do
      expect { described_class.new String}.to raise_error "entity_class argument must extend ActiveRecord.  It was String."
    end

    it "requires writer to respond to entity_json" do
      expect { described_class.new Entry, writer: Object.new }.to raise_error "writer argument must respond to entity_json message."
    end

    it "requires children to be snapshot descriptor objects" do
      expect { described_class.new Entry, children: [String] }.to raise_error "children must all be SnapshotDescriptor instances."
    end

    it "uses default writer if writer is blank" do
      c = SnapshotDescriptor.new Entry
      expect(c.json_writer).to be_a SnapshotWriter
    end
  end

  describe "entity_json" do
    subject { SnapshotDescriptor.new Entry, writer: writer }

    it "uses the defined writer to write json" do
      expect(subject.entity_json Entry.new).to eq json
    end

    it "raises an error if given entity is not the defined entity in the descriptor" do
      expect {subject.entity_json "Testing"}.to raise_error "Invalid entity. Expected Entry but received String."
    end

    it "returns blank string if entity is nil" do
      expect(subject.entity_json nil).to eq ""
    end
  end

  describe "for" do
    it "allows creation of descriptor chains" do
      descriptor = SnapshotDescriptor.for(Entry, {
        commercial_invoices: {
          type: CommercialInvoice,
          children: {
            commercial_invoice_lines: {
              type: CommercialInvoiceLine
            }
          }
        },
        broker_invoices: {
          type: BrokerInvoice,
          children: {
            broker_invoice_line: {
              type: BrokerInvoiceLine
            }
          }
        }
      }, writer: writer)

      expect(descriptor.entity_json Entry.new).to eq json
      expect(descriptor.children.size).to eq 2
      expect(descriptor.children.first.entity_class).to eq CommercialInvoice
      expect(descriptor.children.first.children.first.entity_class).to eq CommercialInvoiceLine

      expect(descriptor.children.second.entity_class).to eq BrokerInvoice
      expect(descriptor.children.second.children.first.entity_class).to eq BrokerInvoiceLine
    end

    it "allows for directly referencing core module classes as 'descriptor' attribute to use their snapshot descriptor" do
      repo = {}
      repo[Folder] = CoreModule::FOLDER.snapshot_descriptor
      descriptor = SnapshotDescriptor.for(Order, {
        folders: { descriptor: Folder }
      }, descriptor_repository: repo)

      # This test relies on knowing the snapshot structure of folder
      expect(descriptor.children.size).to eq 1
      child = descriptor.children.first
      expect(child.entity_class).to eq Folder
      grandchildren = child.children
      expect(grandchildren.size).to eq 3

      grandchild_classes = grandchildren.map {|c| c.entity_class }
      expect(grandchild_classes).to include Comment
      expect(grandchild_classes).to include Attachment
      expect(grandchild_classes).to include Group
    end
  end

end