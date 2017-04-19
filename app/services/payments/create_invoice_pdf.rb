module Payments
  class CreateInvoicePdf
    TABLE_HEADERS = ["DESCRIPTION", "PERIOD", "UNITS", "UNIT PRICE (chf)", "AMOUNT (chf)"].freeze
    PERIOD_FORMAT = '%d.%m.%Y'.freeze

    def initialize(invoice)
      @invoice = invoice
      @charge = Stripe::Charge.retrieve(invoice.charge_id)
      @account = invoice.account
      @address = invoice.address
      @path_to_assets = Rails.root.join('assets').to_s
    end

    def call
      pdf_file = File.open(generate_pdf_file)
      generic_file = GenericFile.create!(file: pdf_file)
      @invoice.update!(generic_file: generic_file)
      pdf_file.close
      FileUtils.rm_f(pdf_file)
    end

    private

    def generate_pdf_file
      pdf = Prawn::Document.new(page_size: 'A4')
      pdf.font_families.update(
        'Lato' => {
          normal: "#{@path_to_assets}/fonts/Lato-Regular.ttf",
          bold: "#{@path_to_assets}/fonts/Lato-Bold.ttf"
        }
      )
      pdf.font 'Lato', size: 11
      pdf.fill_color '1A3F4D'

      I18n.with_locale(@account.default_locale) do
        pdf.image "#{@path_to_assets}/images/logotype-yalty.png", width: 130

        pdf.text '<u>Invoiced to:</u>', align: :right, inline_format: true

        if @adress.present?
          pdf.move_down 5
          pdf.text "#{@address.company_name}", align: :right
          pdf.text "#{@address.address_1}", align: :right
          pdf.text "#{@address.address_2}", align: :right
          pdf.text "#{@address.postalcode} #{@address.city}, #{@address.country}", align: :right
          pdf.text "#{@address.region}", align: :right
        else
          pdf.move_down 50
        end

        pdf.text '<u>INVOICE DETAILS</u>', inline_format: true, size: 16
        pdf.text "Billing Date: #{localized_date(@invoice.date)}"
        pdf.text "Period: #{localized_date(@invoice.period_start)} - #{localized_date(@invoice.period_end)}"
        pdf.text "Invoice N<sup>o</sup>: #{@invoice.receipt_number}", inline_format: true

        pdf.move_down 20
        pdf.text "Billing account: #{@account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
        pdf.move_down 20

        pdf.table(table_data) do
          cells.border_width = 1
          cells.border_color = 'f2f9f6'

          row(0).background_color = 'f2f9f6'
          row(-1).borders = []
          row(-1).columns(-2..-1).borders = [:top, :bottom, :left, :right]
          row(-2).borders = []
          row(-2).columns(-2..-1).borders = [:top, :bottom, :left, :right]

          column(3).width = 120
        end

        pdf.move_down 20
        pdf.text "Your <b>#{@charge.source.brand}</b> ending in <b>#{@charge.source.last4}</b> " +
          "was charged CHF <b>#{in_chf(@invoice.amount_due)}</b>. This charge will appear from " +
          "\"yalty\" on your statement. <b>Questions?</b> Please contact us: " +
          "<b>#{ENV['YALTY_BILLING_EMAIL']}</b>", inline_format: true

        pdf.bounding_box([0, pdf.bounds.bottom + 25], width: 595.28) do
          pdf.text "YALTY SA, c/o Y. LUGRIN, Ch. du Boisy 10, 1004 Lausanne, " +
            "#{ENV['YALTY_BILLING_EMAIL']}\nTVA Number: #{ENV['YALTY_TVA_NUMBER']}"
        end
      end

      pdf_file_path = Rails.root.join('tmp', "#{@invoice.id}.pdf")
      pdf.render_file pdf_file_path
      pdf_file_path
    end

    def table_data
      line_items.unshift(TABLE_HEADERS).push(subtotal_and_tax, total)
    end

    def line_items
      subscription_items + adjustment_items
    end

    def subscription_items
      @invoice.lines.data.select { |line| line.type.eql?('subscription') }.map do |line|
        [
          line.plan.name,
          period(line.period_start, line.period_end),
          units(line),
          unit_price(line),
          in_chf(line.amount)
        ]
      end
    end

    def adjustment_items
      @invoice.lines.data
        .select { |l| l.type.eql?("invoiceitem") }
        .group_by { |l| [l.plan.name, l.period_start.to_date, l.period_end.to_date] }
        .map do |set|
          amount_sum = set.second.sum(&:amount)
          next if amount_sum.zero?
          [
            "Adjustment\n#{set.first[0]}",
            period(set.first[1], set.first[2]),
            nil,
            nil,
            in_chf(amount_sum)
          ]
        end
    end

    def subtotal_and_tax
      [nil, nil, nil,
        "Subtotal in CHF\n#{in_chf(@invoice.subtotal)} * TVA(#{@invoice.tax_percent.to_s}%)",
        "#{in_chf(@invoice.subtotal)}\n#{in_chf(@invoice.tax)}"
      ]
    end

    def total
      [nil, nil, nil, "TOTAL DUE IN CHF", "#{in_chf(@invoice.amount_due)}"]
    end

    def period(start_date, end_date)
      "#{start_date.strftime(PERIOD_FORMAT)} to #{end_date.strftime(PERIOD_FORMAT)}"
    end

    def units(line)
      return unless line.type.eql?('subscription')
      line.quantity
    end

    def unit_price(line)
      return unless line.type.eql?('subscription')
      in_chf(line.plan.amount)
    end

    def in_chf(amount)
      amount / 100.0
    end

    def localized_date(date)
      I18n.localize(date)
    end
  end
end
