describe LinkableAttachment do
  context 'integrity checks' do
    it 'requires model_field_uid' do
      a = described_class.create(value: 'abc')
      expect(a.errors.full_messages.size).to eq(1)
    end

    it 'requires value' do
      a = described_class.create(model_field_uid: 'prod_uid')
      expect(a.errors.full_messages.size).to eq(1)
    end

    it 'saves with model_field_uid and value' do
      a = described_class.create(model_field_uid: 'prod_uid', value: 'abc')
      expect(a.errors).to be_empty
      expect(a.id).to be > 0
    end
  end

  context 'attachment' do
    it 'allows an attachment to be created' do
      linkable = FactoryBot(:linkable_attachment)
      att = linkable.create_attachment
      expect(att.attachable).to eq(linkable)
    end
  end

  context 'link trigger' do
    it 'calls submit attachment link processing to delayed_job on save' do
      expect(LinkedAttachment).to receive(:delay).and_return(LinkedAttachment)
      described_class.create(model_field_uid: 'ord_ord_date', value: '2011-01-01')
    end

    it 'adds linked model fields to memcached on save' do
      expect_any_instance_of(TestExtensions::MockCache).to receive(:set).with("LinkableAttachment:model_field_uids", ['ord_ord_num'])
      described_class.create(model_field_uid: 'ord_ord_num', value: 'v')
    end
  end

  describe 'model_field' do
    it 'returns a good model field' do
      linkable = FactoryBot(:linkable_attachment, model_field_uid: 'ord_ord_num')
      expect(linkable.model_field.uid).to eq(:ord_ord_num)
    end

    it 'returns nil for a bad model filed' do
      expect(FactoryBot(:linkable_attachment, model_field_uid: 'somethingbad').model_field).to be_nil
    end
  end

  describe 'model_field_uids' do
    it 'returns distinct list of model_field_uids in table' do
      ['f1', 'f2', 'f3', 'f1', 'f2', 'f4'].each {|m| FactoryBot(:linkable_attachment, model_field_uid: m)}

      uids = described_class.model_field_uids
      expect(uids.to_a.sort).to eq(['f1', 'f2', 'f3', 'f4'])
    end

    it 'returns an empty array if no records' do
      expect(described_class.model_field_uids).not_to be nil
    end

    it 'tries to get model_fields from cache before hitting db' do
      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with("LinkableAttachment:model_field_uids").and_return(nil)
      described_class.model_field_uids
    end
  end
end
