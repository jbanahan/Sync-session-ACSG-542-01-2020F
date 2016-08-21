require "spec_helper"

describe OpenChain::Api::DescriptorBasedApiEntityJsonizer do

  let (:order) { Factory(:order) }
  let (:user) { Factory(:user) }

  let (:folder) {
    # Use folder since it's a small object that is snapshot descriptor based
    folder = order.folders.create!  name: "Folder", created_by: user, base_object: order
    folder.comments.create! user: user, subject: "Comment", body: "Body"
    folder.groups << Group.use_system_group("code", name: "Group")

    folder
  }

  describe "entity_to_json" do
    it 'renders jsonized output for model fields requested' do
      json = subject.entity_to_json user, folder, [:fld_name, :cmt_subject, :grp_name]
      expect(ActiveSupport::JSON.decode(json)).to eq({
        "folder" => {
          'id' => folder.id,
          'fld_name' => "Folder",
          'comments' => [
            {
              'id' => folder.comments.first.id,
              'cmt_subject' => "Comment"
            }
          ],
          'groups' => [
            {
              'id' => folder.groups.first.id,
              'grp_name' => "Group"
            }
          ]
        }
      })
    end

    it 'skips child and grand-child levels that did not have model fields requested for them' do
      json = subject.entity_to_json user, folder, [:fld_name]
      expect(ActiveSupport::JSON.decode(json)).to eq({
        "folder" => {
          'id' => folder.id,
          'fld_name' => "Folder"
        }
      })
    end

    it 'skips grand-child levels that did not have model fields requested for them' do
      folder
      json = subject.entity_to_json user, order, [:ord_ord_num, :fld_name]
      expect(ActiveSupport::JSON.decode(json)).to eq({
        "order" => {
          'id' => order.id,
          'ord_ord_num' => order.order_number,
          'folders' => [{
            'id' => folder.id,
            'fld_name' => "Folder"
          }]
        }
      })
    end

    it 'does not skip intermediary levels with no model fields if child levels have fields selected' do
      folder
      json = subject.entity_to_json user, order, [:ord_ord_num, :cmt_subject]
      expect(ActiveSupport::JSON.decode(json)).to eq({
        "order" => {
          'id' => order.id,
          'ord_ord_num' => order.order_number,
          'folders' => [{
            'id' => folder.id,
            'comments' => [{
              'id' => folder.comments.first.id,
              'cmt_subject' => "Comment"
            }]
          }]
        }
      })
    end

    it 'sends nil/null for values not present in the entity at each level' do
      folder.name = nil
      json = subject.entity_to_json user, folder, [:fld_name]

      expect(ActiveSupport::JSON.decode(json)).to eq({
        "folder" => {
          'id' => folder.id,
          'fld_name' => nil
        }
      })
    end

    it "validates user access to model fields" do
      allow_any_instance_of(ModelField).to receive(:can_view?).with(user).and_return false
      json = subject.entity_to_json user, folder, [:fld_name, :cmt_subject, :grp_name]
      expect(ActiveSupport::JSON.decode(json)).to eq({'folder'=>{'id'=>folder.id}})
    end

    it "skips invalid model field names" do
      json = subject.entity_to_json user, folder, [:fld_name_blah, :cmt_subject_blah, :grp_name_blah]
      expect(ActiveSupport::JSON.decode(json)).to eq({'folder'=>{'id'=>folder.id}})
    end

    it "raises an error for modules that don't have snapshot descriptors" do
      expect {subject.entity_to_json user, BrokerInvoice.new, [:bi_suffix]}.to raise_error(/Missing snapshot_descriptor for/)
    end
  end

end
