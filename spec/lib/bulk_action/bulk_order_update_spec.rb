describe OpenChain::BulkAction::BulkOrderUpdate do
  describe "#act" do
    before :each do
      @ord = create(:order)
      @u = create(:master_user, order_edit:true, order_view:true)
      @bpl = create(:bulk_process_log)
      field_names = [:ord_ord_date, :ord_revised_date, :ord_window_start, :ord_window_end, :ord_first_exp_del]
      @mf_list = CoreModule::ORDER.model_fields(@u) { |mf| field_names.include? mf.uid}
      @date = Array.new(5) { |i| Date.new(2016, 1, i + 1)}
      @opts = {'ord_ord_date' => @date[0], 'ord_revised_date' => @date[1], 'ord_window_start' => @date[2],
              'ord_window_end' => @date[3], 'ord_first_exp_del' => @date[4]}
    end

    it "updates the order" do
      described_class.act @u, @ord.id, @opts, @bpl, 99
      @ord.reload
      expect(@mf_list[:ord_ord_date].process_export(@ord, @u)).to eq @date[0]
      expect(@mf_list[:ord_revised_date].process_export(@ord, @u)).to eq @date[1]
      expect(@mf_list[:ord_window_start].process_export(@ord, @u)).to eq @date[2]
      expect(@mf_list[:ord_window_end].process_export(@ord, @u)).to eq @date[3]
      expect(@mf_list[:ord_first_exp_del].process_export(@ord, @u)).to eq @date[4]
      expect(@bpl.change_records.count).to eq 1
      expect(@bpl.change_records.first.record_sequence_number).to eq 99
      expect(@ord.entity_snapshots.count).to eq 1
    end

    it "writes an error if user can't update" do
      allow_any_instance_of(Order).to receive(:can_edit?).and_return false
      @ord.reload
      described_class.act @u, @ord.id, @opts, @bpl, 99

      expect(@mf_list[:ord_ord_date].process_export(@ord, @u)).to be_nil
      expect(@bpl.change_records.count).to eq 1
      cr = @bpl.change_records.first
      expect(cr).to be_failed
    end
  end
end