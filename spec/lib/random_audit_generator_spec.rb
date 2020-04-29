describe OpenChain::RandomAuditGenerator do
  describe "run" do
    let(:results) do
      [ {row_key: 1, result: [ "a" ]},
        {row_key: 1, result: [ "b" ]},
        {row_key: 1, result: [ "c" ]},
        {row_key: 2, result: [ "d" ]},
        {row_key: 3, result: [ "e" ]},
        {row_key: 3, result: [ "f" ]},
        {row_key: 4, result: [ "g" ]},
        {row_key: 4, result: [ "h" ]},
        {row_key: 4, result: [ "i" ]},
        {row_key: 4, result: [ "j" ]} ]
    end

    it "performs header-level audit" do
      expect(described_class).to receive(:choose).with(2, [1, 2, 3, 4]).and_return [4, 2]
      expect(described_class.run results, 50, "header").to eq [{row_key: 2, result: [ "d" ]},
                                                               {row_key: 4, result: [ "g" ]},
                                                               {row_key: 4, result: [ "h" ]},
                                                               {row_key: 4, result: [ "i" ]},
                                                               {row_key: 4, result: [ "j" ]}]
    end

    it "returns at least one entity for header-level audit" do
      expect(described_class).to receive(:choose).with(1, [1, 2, 3, 4]).and_return [4]
      expect(described_class.run results, 4, "header").to eq [{row_key: 4, result: [ "g" ]},
                                                              {row_key: 4, result: [ "h" ]},
                                                              {row_key: 4, result: [ "i" ]},
                                                              {row_key: 4, result: [ "j" ]}]
    end

    it "performs line-level audit" do
      expect(described_class).to receive(:choose).with(5, (0..9).to_a).and_return [5, 3, 9, 2, 8]
      expect(described_class.run results, 50, "line").to eq [{row_key: 1, result: [ "c" ]},
                                                             {row_key: 2, result: [ "d" ]},
                                                             {row_key: 3, result: [ "f" ]},
                                                             {row_key: 4, result: [ "i" ]},
                                                             {row_key: 4, result: [ "j" ]}]
    end

    it "returns at least one record for line-level audit" do
      expect(described_class).to receive(:choose).with(1, (0..9).to_a).and_return [5]
      expect(described_class.run results, 4, "line").to eq [{row_key: 3, result: [ "f" ]}]
    end
  end

  describe "choose" do
    it "selects n different elements of input array" do
      expect(Random).to receive(:rand).with(10).and_return 2
      expect(Random).to receive(:rand).with(9).and_return 6
      expect(Random).to receive(:rand).with(8).and_return 1
      expect(Random).to receive(:rand).with(7).and_return 0
      expect(Random).to receive(:rand).with(6).and_return 5
      expect(described_class.choose 5, (1..10).to_a).to eq [3, 8, 2, 1, 10]
    end
  end

end
