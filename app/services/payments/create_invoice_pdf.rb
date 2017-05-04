module Payments
  class CreateInvoicePdf
    PERIOD_FORMAT = '%d.%m.%Y'.freeze

    def initialize(invoice)
      @invoice = invoice.reload
      @account = invoice.account
      customer = Stripe::Customer.retrieve(@account.customer_id)
      @card = customer.sources.find { |src| src.id.eql?(customer.default_source) }
      @address = invoice.address
      @path_to_assets = Rails.root.join('assets').to_s
      @pdf = initialize_pdf
    end

    def call
      pdf_file = File.open(generate_pdf_file)

      ActiveRecord::Base.transaction do
        generic_file = GenericFile.create!(file: pdf_file)
        @invoice.update!(generic_file: generic_file)
      end

      pdf_file.close
      FileUtils.rm_f(pdf_file)
    end

    private

    def initialize_pdf
      Prawn::Document.new(page_size: 'A4').tap do |pdf|
        pdf.font_families.update(
          'Lato' => {
            normal: "#{@path_to_assets}/fonts/Lato-Regular.ttf",
            bold: "#{@path_to_assets}/fonts/Lato-Bold.ttf"
          }
        )
        pdf.font 'Lato', size: 11
        pdf.fill_color '1A3F4D'
      end
    end

    def generate_pdf_file
      I18n.with_locale(@account.default_locale) do
        @pdf.image "#{@path_to_assets}/images/logotype-yalty.png", width: 130
        pdf_address
        pdf_invoice_details
        pdf_table
        pdf_charge_details
        pdf_footer
      end

      pdf_file_path = Rails.root.join('tmp', "#{@invoice.id}.pdf")
      @pdf.render_file pdf_file_path
      pdf_file_path
    end

    def pdf_address
      @pdf.text "<u>#{I18n.t('invoice_pdf.invoiced_to')}:</u>", align: :right, inline_format: true
      if @adress.present?
        @pdf.move_down 5
        @pdf.text @address.company_name, align: :right
        @pdf.text @address.address_1, align: :right
        @pdf.text @address.address_2, align: :right
        @pdf.text "#{@address.postalcode} #{@address.city}, #{@address.country}", align: :right
        @pdf.text @address.region, align: :right
      else
        @pdf.move_down 50
      end
    end

    def pdf_invoice_details
      @pdf.text "<u>#{I18n.t('invoice_pdf.invoice_details')}</u>", inline_format: true, size: 16
      @pdf.text "#{I18n.t('invoice_pdf.billing_date')}: #{localized_date(@invoice.date)}"
      @pdf.text "#{I18n.t('invoice_pdf.period')}: #{localized_date(@invoice.period_start)}" \
        "- #{localized_date(@invoice.period_end)}"
      @pdf.text "#{I18n.t('invoice_pdf.invoice')} N<sup>o</sup>: #{@invoice.receipt_number}",
        inline_format: true

      @pdf.move_down 20
      @pdf.text "#{I18n.t('invoice_pdf.billing_account')}: " \
        "#{@account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
      @pdf.move_down 20
    end

    def pdf_table
      @pdf.table(table_data) do
        cells.border_width = 1
        cells.border_color = 'f2f9f6'

        row(0).background_color = 'f2f9f6'
        row(-1).borders = []
        row(-1).columns(-2..-1).borders = [:top, :bottom, :left, :right]
        row(-2).borders = []
        row(-2).columns(-2..-1).borders = [:top, :bottom, :left, :right]

        column(1).width = 75
        column(2).width = 45
        column(3).width = 120
      end

      @pdf.move_down 20
    end

    def pdf_charge_details
      @pdf.text I18n.t(
        'invoice_pdf.card_charged',
        brand: @card.brand,
        last4: @card.last4,
        amount_due: in_chf(@invoice.amount_due),
        email: ENV['YALTY_BILLING_EMAIL']
      ), inline_format: true
    end

    def pdf_footer
      @pdf.bounding_box([0, @pdf.bounds.bottom + 25], width: 595.28) do
        @pdf.text I18n.t(
          'invoice_pdf.yalty_data',
          email: ENV['YALTY_BILLING_EMAIL'],
          tva: ENV['YALTY_TVA_NUMBER']
        )
      end
    end

    def table_data
      table_headers = [
        I18n.t('invoice_pdf.description'),
        I18n.t('invoice_pdf.period').upcase,
        I18n.t('invoice_pdf.units'),
        I18n.t('invoice_pdf.unit_price') + "\n(chf)",
        I18n.t('invoice_pdf.amount') + "\n(chf)"
      ]
      line_items.unshift(table_headers).push(subtotal_and_tax, total)
    end

    def line_items
      subscription_items + adjustment_items
    end

    def subscription_items
      @invoice.lines.data.select { |line| line.type.eql?('subscription') }.map do |line|
        [
          I18n.t("invoice_pdf.plans.#{line.plan.id}"),
          period(line.period_start, line.period_end),
          units(line),
          unit_price(line),
          in_chf(line.amount)
        ]
      end
    end

    def adjustment_items
      @invoice
        .lines
        .data
        .select { |l| l.type.eql?('invoiceitem') }
        .group_by { |l| [l.plan.name, l.period_start.to_date, l.period_end.to_date] }
        .map do |set|
          amount_sum = set.second.sum(&:amount)
          next if amount_sum.zero?
          [
            "#{I18n.t('invoice_pdf.adjustment')}\n#{set.first[0]}",
            period(set.first[1], set.first[2]),
            nil,
            nil,
            in_chf(amount_sum)
          ]
        end.compact
    end

    def subtotal_and_tax
      headers = "#{I18n.t('invoice_pdf.subtotal_in_chf')}\n#{in_chf(@invoice.subtotal)} " \
        "* TVA(#{@invoice.tax_percent.to_i}%)"
      [nil, nil, nil, headers, "#{in_chf(@invoice.subtotal)}\n#{in_chf(@invoice.tax)}"]
    end

    def total
      [nil, nil, nil, I18n.t('invoice_pdf.total_due_in_chf'), in_chf(@invoice.amount_due)]
    end

    def period(start_date, end_date)
      "#{start_date.strftime(PERIOD_FORMAT)} - #{end_date.strftime(PERIOD_FORMAT)}"
    end

    def units(line)
      line.quantity if line.type.eql?('subscription')
    end

    def unit_price(line)
      in_chf(line.plan.amount) if line.type.eql?('subscription')
    end

    def in_chf(amount)
      return 0 unless amount.present?
      format('%.2f', amount / 100.00)
    end

    def localized_date(date)
      I18n.localize(date)
    end
  end
end
