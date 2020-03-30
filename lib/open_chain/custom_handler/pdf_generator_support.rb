require 'prawn'

module OpenChain; module CustomHandler; module PdfGeneratorSupport

  def text_box document, text, at, width, height, overflow: :shrink_to_fit, align: :left
    document.text_box text.to_s.strip, at: at, width: width, height: height, overflow: overflow, align: align
  end


  # Text box with an outline.
  def b_text_box document, text, at, width, height, overflow: :shrink_to_fit, align: :left
    document.bounding_box([at[0], at[1]], width: width, height: height) do
      document.stroke_bounds
    end

    text_box document, text, at, width, height, overflow: overflow, align: align
  end

  def add_page_numbers doc, at: nil
    if at.nil?
      page_width = doc.bounds.width.to_f
      at = [(page_width / 2) - 25, -10]
    end

    doc.number_pages "<page> of <total>", width: 50, at: at, align: :center
  end


  # Creates a new PDF document
  # Options:
  # page_size: "LETTER" is default, it's almost always what we'll want...but you can use any value listed in PDF::Core::PageGeometry
  # layout: :portrait, or :landscape.  Defaults to :portrait.
  # metadata: Page metadata can go here by default CreateDate, Creator and Producer is set.
  # document_options: Any other option prawn pdfs accept can be passed here (for instance, non-default margins)
  def pdf_document page_size: "LETTER", layout: :portrait, metadata: { Creator: MasterSetup.application_name, Producer: MasterSetup.application_name, CreationDate: Time.now}, document_options: {}
    if document_options[:info]
      document_options[:info] = metatdata.merge document_options[:info]
    else
      document_options[:info] = metadata
    end

    document_options[:page_size] = page_size
    document_options[:page_layout] = layout

    Prawn::Document.new document_options
  end

end; end; end;
