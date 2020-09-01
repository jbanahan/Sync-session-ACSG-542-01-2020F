describe OpenChain::CustomHandler::Generator315::Tradelens::RequestDataExtractor do
  let(:data_315) do
    OpenStruct.new container_numbers: ["cont_num1", "cont_num2"], master_bills: ["MAEUMBOL1", "MAEUMBOL2"],
                   transport_mode_code: 40, event_date: Date.new(2020, 3, 15)
  end

  let(:request) do
    {originatorName: "Damco Customs Services Inc",
     originatorId: "DCSI",
     eventSubmissionTime8601: "2020-03-20T00:00:00.000+00:00",
     equipmentNumber: "cont_num1",
     billOfLadingNumber: "MAEUMBOL1",
     eventOccurrenceTime8601: "2020-03-15T00:00:00.000+00:00"}
  end

  describe "request" do
    it "converts data_315 into request hash" do
      extractor = described_class.new data_315

      req = nil
      Timecop.freeze(DateTime.new(2020, 3, 20)) { req = extractor.request }

      expect(req).to eq request
    end

    it "removes SCAC from master bill for sea shipment" do
      data_315.transport_mode_code = 10
      extractor = described_class.new data_315

      req = nil
      Timecop.freeze(DateTime.new(2020, 3, 20)) { req = extractor.request }

      expect(req).to eq(request.merge(billOfLadingNumber: "MBOL1"))
    end

    it "includes UN/Locode info if it exists" do
      data_315.unlocode = "ABCD"
      extractor = described_class.new data_315

      req = nil
      Timecop.freeze(DateTime.new(2020, 3, 20)) { req = extractor.request }

      expect(req).to eq(request.merge({location: {type: "UN/LOCODE", value: "ABCD"}}))
    end

    it "includes other port identifier if it exists" do
      data_315.unlocode = nil
      data_315.gln = "12345"
      extractor = described_class.new data_315

      req = nil
      Timecop.freeze(DateTime.new(2020, 3, 20)) { req = extractor.request }

      expect(req).to eq(request.merge({location: {gln: "12345"}}))
    end
  end
end
