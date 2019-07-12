require 'axlsx'

# Simple interface for building a chart within an .xlsx Excel file.
class XlsxChartBuilder

  # This is a simple wrapper class that is here as a means to track raw access to any chart functionality
  # that might be needed, and reduce widescale changes from needing to be made systemwide should we ever switch
  # to another XLSX gem.
  class XlsxChart
    attr_reader :raw_chart
    attr_reader :x_axis_labels

    def initialize chart, x_axis_labels
      @raw_chart = chart
      @x_axis_labels = x_axis_labels
    end

    # Adds a series of data to the chart.
    #
    # data - array of numbers
    # series_title - label for the series/line/etc. (e.g. "2018")
    # color - hex color code
    def add_data data, series_title, color
      @raw_chart.add_series :data => data, :title => series_title, :color => color, :labels => @x_axis_labels
    end
  end

  # Creates a new line chart in the worksheet.
  # 
  # Returns nothing: the XlsChart wrapper object must be dealt with (i.e. adding data) via block.
  #
  # upper_left_corner - The top left corner position of the chart.
  #     Can be either an array of the format [column, row] or an Excel coordinate of the format "B3".  Chart data may
  #     be written to/over this cell.
  # lower_right_corner - The lower right corner position of the chart.  Note that the space the chart needs includes the legend.
  #     Can be either an array of the format [column, row] or an Excel coordinate of the format "B3".  Chart data will
  #     not be written to/over this cell: it's more of a boundary.  The chart will be written to the cell to its
  #     immediate left.  If you want to have a chart that covers columns A-F, specify something like "A1" and "G10" as your bounds.
  # legend_position - options: :bottom, :left, :right, :top, :top_right
  # x_axis_labels - Alternate labels to replace the default incrementing numbers used in the horizontal x-axis.  Optional.  Nil results in default.
  def create_line_chart sheet, title, upper_left_corner, lower_right_corner, legend_position: :bottom, x_axis_labels: nil
    chart = XlsxChart.new(sheet.raw_sheet.add_chart(Axlsx::LineChart, :title=>title, :start_at=> upper_left_corner, :end_at=>lower_right_corner, :legend_position => convert_legend_position(legend_position)), x_axis_labels)
    yield chart if block_given?
    nil
  end

  private
    def convert_legend_position pos
      conv_pos = :b
      case pos
        when :bottom
          conv_pos = :b
        when :left
          conv_pos = :l
        when :right
          conv_pos = :r
        when :top
          conv_pos = :t
        when :top_right
          conv_pos = :tr
      end
      conv_pos
    end

end
