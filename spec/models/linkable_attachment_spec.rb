describe LinkableAttachment do
  context 'integrity checks' do
    it 'should require model_field_uid' do
      a = LinkableAttachment.create(:value=>'abc')
      expect(a.errors.full_messages.size).to eq(1)
    end
    it 'should require value' do
      a = LinkableAttachment.create(:model_field_uid=>'prod_uid')
      expect(a.errors.full_messages.size).to eq(1)
    end
    it 'should save with model_field_uid and value' do
      a = LinkableAttachment.create(:model_field_uid=>'prod_uid',:value=>'abc')
      expect(a.errors).to be_empty
      expect(a.id).to be > 0
    end
  end
  context 'attachment' do
    it 'should allow an attachment to be created' do
      linkable = Factory(:linkable_attachment)
      att = linkable.create_attachment
      expect(att.attachable).to eq(linkable)
    end
  end
  context 'link trigger' do
    it 'should call submit attachment link processing to delayed_job on save' do
      expect(LinkedAttachment).to receive(:delay).and_return(LinkedAttachment)
      LinkableAttachment.create(:model_field_uid=>'ord_ord_date',:value=>'2011-01-01')
    end
    it 'should add linked model fields to memcached on save' do
      expect_any_instance_of(TestExtensions::MockCache).to receive(:set).with("LinkableAttachment:model_field_uids",['ord_ord_num'])
      LinkableAttachment.create(:model_field_uid=>'ord_ord_num',:value=>'v')
    end
  end
  describe 'model_field' do
    it 'should return a good model field' do
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num')
      expect(linkable.model_field.uid).to eq(:ord_ord_num)
    end
    it 'should return nil for a bad model filed' do
      expect(Factory(:linkable_attachment,:model_field_uid=>'somethingbad').model_field).to be_nil
    end
  end
  describe 'model_field_uids' do
    it 'should return distinct list of model_field_uids in table' do
      ['f1','f2','f3','f1','f2','f4'].each {|m| Factory(:linkable_attachment, :model_field_uid=>m)}

      uids = LinkableAttachment.model_field_uids
      expect(uids.to_a.sort).to eq(['f1','f2','f3','f4'])
    end
    it 'should return an empty array if no records' do
      expect(LinkableAttachment.model_field_uids).not_to be nil 
    end
    it 'should try to get model_fields from cache before hitting db' do
      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with("LinkableAttachment:model_field_uids").and_return(nil)
      LinkableAttachment.model_field_uids
    end
  end
end
