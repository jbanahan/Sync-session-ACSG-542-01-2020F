describe PowerOfAttorney do
  let(:company) { FactoryBot(:company) }
  let(:user) { FactoryBot(:user, company_id: company.id) }

  let(:attributes) do
    {company_id: company.id,
     uploaded_by: user.id,
     start_date: '2011-12-01',
     expiration_date: '2011-12-31',
     attachment_file_name: 'Somedocument.odt'}
  end

  it "creates PowerOfAttorney given valid attributes" do
    described_class.create!(attributes)
  end

  it "requires attachment" do
    expect(described_class.new(attributes.merge(attachment_file_name: ''))).not_to be_valid
  end

  it "shold require user that created it" do
    expect(described_class.new(attributes.merge(uploaded_by: ''))).not_to be_valid
  end

  it "requires company" do
    expect(described_class.new(attributes.merge(company_id: ''))).not_to be_valid
  end

  it "requires start date" do
    expect(described_class.new(attributes.merge(start_date: ''))).not_to be_valid
  end

  it "requires expiration date" do
    expect(described_class.new(attributes.merge(expiration_date: ''))).not_to be_valid
  end
end
