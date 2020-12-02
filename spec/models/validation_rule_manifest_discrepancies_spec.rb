describe ValidationRuleManifestDiscrepancies do
  let(:rule) { described_class.new }
  let(:entry) { create(:entry) }

  describe 'run_validation' do
    it 'passes if both Qty and MnQty match' do
      EntryComment.create(entry: entry, body: "H OERT 201702I07378 Qty: 1931 CTN MnQty: 1931")

      expect(rule.run_validation(entry)).to be_nil
    end

    it 'gracefully handles just numbers without a designation in regex checks' do
      EntryComment.create(entry: entry, body: "H OERT 205702I04779 Qty: 29 MnQty: 29")

      expect(rule.run_validation(entry)).to be_nil
    end

    it 'gracefully handles nils in regex checks' do
      EntryComment.create(entry: entry, body: "H OERT 205702I04779 Qty: MnQty: ")

      expect(rule.run_validation(entry)).to be_nil
    end

    it 'fails if Qty and MnQty do not match' do
      EntryComment.create(entry: entry, body: "H OERT 201702I07378 Qty: 1932 CTN MnQty: 1931")

      expect(rule.run_validation(entry)).to eql("Bill of Lading OERT201702I07378 Quantity of 1931 does not match Manifest Quantity of 1932.")
    end

    it 'passes even if older entry comments are incorrect' do
      EntryComment.create(entry: entry, body: "H OERT 201702I07378 Qty: 1932 CTN MnQty: 1931", generated_at: 5.minutes.ago)
      EntryComment.create(entry: entry, body: "H OERT 201702I07378 Qty: 1931 CTN MnQty: 1931", generated_at: 1.minute.ago)

      expect(rule.run_validation(entry)).to be_nil
    end

    it 'handles no entry comments gracefully' do
      expect(rule.run_validation(entry)).to be_nil
    end
  end
end