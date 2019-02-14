describe OpenChain::NameIncrementer do
  let(:list) { ["David's Search", "David's Search (COPY)", "David's Search (COPY 2)", "Derek's Search"] }

  it "returns original name if it doesn't appear in the list" do
    expect(described_class.increment "Nigel's Search", list).to eq "Nigel's Search"
  end

  it "returns (COPY) if there's one other instance in the list" do
    expect(described_class.increment "Derek's Search", list).to eq "Derek's Search (COPY)"
  end

  it "returns (COPY n) if there are multiple instances in the list" do
    expect(described_class.increment "David's Search (COPY 2)", list).to eq "David's Search (COPY 3)"
    expect(described_class.increment "David's Search (COPY)", list).to eq "David's Search (COPY 3)"
  end
end
