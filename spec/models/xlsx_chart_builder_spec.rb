describe XlsxChartBuilder do

  # There doesn't seem to be a good way to test that charts are being successfully generated programatically.  These
  # tests verify merely that params are passed in an expected manner, and lean heavily on mocking.
  describe "create_line_chart" do
    let(:sheet) { double("sheet") }
    let(:raw_sheet) { double("raw_sheet") }
    let(:raw_chart) { double("raw_chart") }

    it "creates a line chart with default optional parameters" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :b).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4" do |chart|
        expect(chart.raw_chart).to eq raw_chart
        expect(chart.x_axis_labels).to be_nil
      end
    end

    it "creates a line chart with legend bottom-aligned, x-axis labels specified" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :b).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :bottom, x_axis_labels:["A", "B", "C"] do |chart|
        expect(chart.raw_chart).to eq raw_chart
        expect(chart.x_axis_labels).to eq ["A", "B", "C"]
      end
    end

    it "creates a line chart with legend top-aligned" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :t).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :top
    end

    it "creates a line chart with legend left-aligned" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :l).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :left
    end

    it "creates a line chart with legend right-aligned" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :r).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :right
    end

    it "creates a line chart with legend top-right-aligned" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :tr).and_return raw_chart

      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :top_right
    end

    it "handles bogus line chart legend alignment code" do
      expect(sheet).to receive(:raw_sheet).and_return raw_sheet
      expect(raw_sheet).to receive(:add_chart).with(Axlsx::LineChart, :title=>"Echidna's Arf", :start_at=>"A1", :end_at=>"B4", :legend_position => :b).and_return raw_chart

      # Should default to bottom.
      XlsxChartBuilder.new.create_line_chart sheet, "Echidna's Arf", "A1", "B4", legend_position: :wrong
    end
  end

  describe "add_data" do
    it "adds data to a chart" do
      raw_chart = double("raw_chart")
      expect(raw_chart).to receive(:add_series).with :data => [1,2,3], :title => "2018 Data", :color => "FF0000", :labels => ["A", "B", "C"]

      chart = XlsxChartBuilder::XlsxChart.new(raw_chart, ["A", "B", "C"])
      chart.add_data([1,2,3], "2018 Data", "FF0000")
    end
  end

end