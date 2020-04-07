describe OpenChain::DataCrossReferenceUploadPreprocessor do
  describe "preprocessor_for_xref" do
    context "if xref-type missing/unrecognized" do
      it "returns an 'identity' lambda if xref-type unrecognized" do
        preproc = described_class.preprocessors["none"]
        expect(preproc.call("x", "y")).to eq({key: "x", value: "y"})
      end

      it "forces values to text by default" do
        preproc = described_class.preprocessors["none"]
        expect(preproc.call(1.0, 3.2)).to eq({key: "1", value: "3.2"})
      end
    end

    context "asce_mid" do
      let(:target) { "2017-03-15" }
      let(:preproc) { described_class.preprocessors["asce_mid"] }

      it "parses date for M-D-Y, M/D/Y, Y/M/D, Y-M-D" do
        expect(preproc.call("x", "3/15/2017")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "3-15-2017")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "2017-3-15")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "2017/3/15")).to eq({key: 'x', value: target})
      end

      it "returns nil for bad input" do
        expect(preproc.call("x", "3/foo/2017")).to eq({key: 'x', value: nil})
        expect(preproc.call("x", "3/35/2017")).to eq({key: 'x', value: nil})
      end
    end

    context "spi_available_country_combination" do
      let(:preproc) { described_class.preprocessors["spi_available_country_combination"] }

      it "parses input" do
        # Normal case.
        expect(preproc.call("AB", "CD")).to eq({key: "AB#{DataCrossReference.compound_key_token}CD", value: "X"})
        # Whitespace is trimmed.
        expect(preproc.call("EF ", " GH")).to eq({key: "EF#{DataCrossReference.compound_key_token}GH", value: "X"})
        # Nil-handling: almost certainly wouldn't occur in real usage.
        expect(preproc.call(nil, nil)).to eq({key: DataCrossReference.compound_key_token, value: "X"})
      end
    end
  end

end