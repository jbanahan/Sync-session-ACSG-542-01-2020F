require 'spec_helper'

describe OpenChain::BillingComparator do
  describe "Compare" do
    before :each do
      @snapshot = Factory(:entity_snapshot, bucket: "new bucket", doc_path: "new/path", version: "new ver.")
      
      @ec = Class.new(described_class::Comparer) do
              def meth args; Factory(:vfi_invoice); end;
            end

      stub_const("OpenChain::BillingComparator::EntryComparer", @ec)
    end

    it "does nothing if the class name isn't on the approved list" do
      described_class.compare "Foo", @snapshot.recordable, "old bucket", "old/path", "old ver.", @snapshot.bucket, @snapshot.doc_path, @snapshot.version
      expect(VfiInvoice.count).to eq 0
    end

    it "calls the comparer matching its type argument" do
      described_class.compare "Entry", @snapshot.recordable, "old bucket", "old/path", "old ver.", @snapshot.bucket, @snapshot.doc_path, @snapshot.version
      expect(VfiInvoice.count).to eq 1
    end
  end

  describe 'Comparer' do

    it "calls all instance methods of inheriting class" do
      
      class FooComparer < described_class::Comparer
        def meth_1 args; Factory(:vfi_invoice, invoice_number: 1); end;
        def meth_2 args; Factory(:vfi_invoice, invoice_number: 2); end;
        def meth_3 args; Factory(:vfi_invoice, invoice_number: 3); end;
      end
      
      FooComparer.go({})
      expect(VfiInvoice.count).to eq 3
    end
  end

  describe 'ClassificationComparer' do
    before :each do 
      @c = described_class::ProductComparer.new
      @prod = Factory(:product)
      @cl_1 = Factory(:classification)
      @cl_2 = Factory(:classification)
      @s = Factory(:entity_snapshot, recordable: @prod)
      @old_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>@prod.id, "children"=>
                  [{"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_1.id}}, 
                   {"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_2.id}}]}}
    end
  
    describe :check_new do
      it "doesn't do anything if there are no new classifications" do

        new_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>@prod.id, "children"=>
                    [{"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_1.id}}]}}

        @c.should_receive(:get_json_hash).with("old bucket", "old/path", "old ver.").and_return @old_hsh
        @c.should_receive(:get_json_hash).with("new bucket", "new/path", "new ver.").and_return new_hsh

        @c.check_new_classification({id: @prod.id, old_bucket: "old bucket", old_path: "old/path", old_version: "old ver.", 
                                     new_bucket: "new bucket", new_path: "new/path", new_version: "new ver.", new_snapshot_id: @s.id})
        expect(BillableEvent.count).to eq 0
      end

      it "creates a billable event for each new classification on a new product" do
        new_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>@prod.id, "children"=>
                    [{"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_1.id}}, 
                     {"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_2.id}}]}}

        @c.should_receive(:get_json_hash).with("new bucket", "new/path", "new ver.").and_return new_hsh

        @c.check_new_classification({id: @prod.id, old_bucket: nil, old_path: nil, old_version: nil, 
                                     new_bucket: "new bucket", new_path: "new/path", new_version: "new ver.", new_snapshot_id: @s.id})

        expect(BillableEvent.count).to eq 2
        event_1, event_2 = BillableEvent.all
        expect(event_1.eventable).to eq @cl_1
        expect(event_1.event_type).to eq "Classification - New"
        expect(event_1.entity_snapshot).to eq @s
        expect(event_2.eventable).to eq @cl_2
      end

      it "creates a billable event for each new classification on an updated product" do
        cl_3 = Factory(:classification)
        cl_4 = Factory(:classification)

        old_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>@prod.id, "children"=>
                    [{"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_1.id}}, 
                     {"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_2.id}}]}}

        new_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>@prod.id, "children"=>
                    [{"entity"=>{"core_module"=>"Classification", "record_id"=>@cl_2.id}},
                     {"entity"=>{"core_module"=>"Classification", "record_id"=>cl_3.id}},
                     {"entity"=>{"core_module"=>"Classification", "record_id"=>cl_4.id}}]}}

        @c.should_receive(:get_json_hash).with("old bucket", "old/path", "old ver.").and_return old_hsh
        @c.should_receive(:get_json_hash).with("new bucket", "new/path", "new ver.").and_return new_hsh

        @c.check_new_classification({id: @prod.id, old_bucket: "old bucket", old_path: "old/path", old_version: "old ver.", 
                                     new_bucket: "new bucket", new_path: "new/path", new_version: "new ver.", new_snapshot_id: @s.id})

        expect(BillableEvent.count).to eq 2
        event_1, event_2 = BillableEvent.all
        expect(event_1.eventable).to eq cl_3
        expect(event_1.event_type).to eq "Classification - New"
        expect(event_1.entity_snapshot).to eq @s
        expect(event_2.eventable).to eq cl_4      
      end
    end
  end

  describe 'EntryComparer' do
    before :each do 
      @c = described_class::EntryComparer.new
      @e = Factory(:entry)
      @s = Factory(:entity_snapshot, recordable: @e)
    end
    
    describe :check_new do
      it "doesn't do anything if there's an old snapshot" do
        @c.check_new({id: @e.id, old_bucket: "development.www-vfitrack-net.snapshots.vfitrack.net", new_snapshot_id: @s.id})
        expect(BillableEvent.count).to eq 0
      end

      it "creates a billable event" do
        @c.check_new({id: @e.id, old_bucket: nil, new_snapshot_id: @s.id})
        event = BillableEvent.first
        expect(event.eventable).to eq @e
        expect(event.entity_snapshot).to eq @s
        expect(event.event_type).to eq "Entry - New"
      end
    end
  end

end