describe LinkedAttachment do
  context 'validations' do
    it 'should require an attachable' do
      a = LinkedAttachment.create(:linkable_attachment=>Factory(:linkable_attachment))
      expect(a.errors.full_messages.size).to eq(1)
    end
    it 'should require a linkable attachment' do
      a = LinkedAttachment.create(:attachable=>Factory(:product))
      expect(a.errors.full_messages.size).to eq(1)
    end
    it 'should save with an attachable and linkable attachment' do
      a = LinkedAttachment.create(:attachable=>Factory(:product), :linkable_attachment=>Factory(:linkable_attachment))
      expect(a.errors).to be_empty
    end
  end

  describe 'static creators' do
    before(:each) do
      non_matching_linkable = Factory(:linkable_attachment)
      non_matching_attachable = Factory(:product)
    end


    describe 'create_from_attachable_by_class_and_id' do
      it "should load object and pass" do
        prod_id = Factory(:product).id
        expect(LinkedAttachment).to receive(:create_from_attachable).with(instance_of(Product)).and_return('x')
        LinkedAttachment.create_from_attachable_by_class_and_id Product, prod_id
      end
    end

    describe 'create_from_attachable' do
      before(:each) do
        @product = Factory(:product, :unit_of_measure=>'uom')
      end
      it 'should do nothing with no matching linkable attachments' do
        r = LinkedAttachment.create_from_attachable(Factory(:product))
        expect(r.size).to eq(0)
        expect(LinkedAttachment.all.size).to eq(0)
      end
      it 'should create 1 with 1 matching linkable attachment' do
        linkable = Factory(:linkable_attachment, :model_field_uid=>'prod_uid', :value=>@product.unique_identifier)
        r = LinkedAttachment.create_from_attachable(@product)
        expect(r.size).to eq(1)
        linked = r.first
        expect(linked.linkable_attachment).to eq(linkable)
        expect(linked.attachable).to eq(@product)
      end
      it 'should create 2 with 2 matching linkable attachments on different model fields' do
        linkables = []
        {'prod_uid'=>@product.unique_identifier, 'prod_uom'=>@product.unit_of_measure}.each {|k, v| linkables << Factory(:linkable_attachment, :model_field_uid=>k, :value=>v)}
        r = LinkedAttachment.create_from_attachable(@product)
        expect(r.size).to eq(2)
        r.each do |linked|
          expect(linkables).to include(linked.linkable_attachment)
          expect(linked.attachable).to eq(@product)
        end
      end
      it 'should do nothing if already linked to all potential matches' do
        2.times {|i| Factory(:linkable_attachment, :model_field_uid=>'prod_uid', :value=>@product.unique_identifier)}
        LinkedAttachment.create_from_attachable(@product) # first time does matching
        expect(LinkedAttachment.create_from_attachable(@product)).to be_empty  # second time does nothing
        expect(LinkedAttachment.all.size).to eq(2)
      end
      it 'should only query for matching mf_uids in linkable_attachments table' do
        # this is a pretty bad test for internal functionality, but if it goes red, you should make sure you haven't made the method to inefficient
        expect(LinkableAttachment).to receive(:model_field_uids).and_return([])
        LinkedAttachment.create_from_attachable @product
      end
    end
    describe 'create_from_linkable_attachment' do
      before(:each) do
        @product = Factory(:product, :unit_of_measure=>'uomx')
        @linkable = Factory(:linkable_attachment, :model_field_uid=>'prod_uom', :value=>@product.unit_of_measure)
      end
      it 'should create 1 with 1 matching attachable' do
        found = LinkedAttachment.create_from_linkable_attachment @linkable
        expect(found.size).to eq(1)
        expect(found.first.attachable).to eq(@product)
        found.first.linkable_attachment == @linkable
      end
      it 'should create 2 with 2 matching attachables' do
        p2 = Factory(:product, :unit_of_measure=>@product.unit_of_measure)
        found = LinkedAttachment.create_from_linkable_attachment @linkable
        expect(found.size).to eq(2)
        products = [@product, p2]
        found.each do |f|
          expect(products).to include f.attachable
          expect(f.linkable_attachment).to eq(@linkable)
        end
      end
      it 'should do nothing with no matching attachable' do
        @linkable.update_attributes(:value=>'somethingelse')
        expect(LinkedAttachment.create_from_linkable_attachment(@linkable)).to be_empty
      end
      it 'should do nothing if already linked to all potential matches' do
        LinkedAttachment.create_from_linkable_attachment @linkable # does the matches
        expect(LinkedAttachment.create_from_linkable_attachment(@linkable)).to be_empty
        expect(LinkedAttachment.all.size).to eq(1)
      end
    end
  end
end
