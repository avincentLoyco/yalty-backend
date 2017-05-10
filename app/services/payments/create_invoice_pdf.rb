module Payments
  class CreateInvoicePdf
    delegate :t, :l, to: I18n

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
      @pdf.text_box "<u>#{t('payment.pdf.header.invoiced_to')}</u>",
        inline_format: true, at: [350, @pdf.cursor - 15]
      @pdf.move_down 15

      if @address.present?
        text = []
        text << @address.company_name if @address.company_name.present?
        text << @address.address_1 if @address.address_1.present?
        text << @address.address_2 if @address.address_2.present?
        text << @address.region if @address.region.present?
        text << "#{@address.postalcode} #{@address.city}, #{@address.country}"
        @pdf.text_box text.join("\n"), at: [350, @pdf.cursor - 15]
      else
        @pdf.text_box @account.company_name, at: [350, @pdf.cursor - 15]
      end
    end

    def pdf_invoice_details
      @pdf.text "<u>#{t('payment.pdf.header.title')}</u>", inline_format: true, size: 16
      @pdf.text t('payment.pdf.header.billing_date',
        billing_date: l(@invoice.date.to_date, format: :long))
      @pdf.text t('payment.pdf.header.period',
        period_start: l(@invoice.period_start.to_date, format: :long),
        period_end: l(@invoice.period_end.to_date, format: :long))
      @pdf.text t('payment.pdf.header.receipt_number',
        receipt_number: @invoice.receipt_number),
        inline_format: true

      @pdf.move_down 20
      @pdf.text t('payment.pdf.header.account',
        domain: "#{@account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}")
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

        column(1).width = 80
        column(2).width = 50
        column(3).width = 120
      end

      @pdf.move_down 20
    end

    def pdf_charge_details
      @pdf.text t(
        'payment.pdf.items.card_charged',
        brand: @card.brand,
        last4: @card.last4,
        amount_due: in_chf(@invoice.amount_due),
        email: ENV['YALTY_BILLING_EMAIL']
      ), inline_format: true
    end

    def pdf_footer
      @pdf.bounding_box([0, @pdf.bounds.bottom + 25], width: 595.28) do
        @pdf.text t(
          'payment.pdf.footer',
          email: ENV['YALTY_BILLING_EMAIL'],
          tva: ENV['YALTY_TVA_NUMBER']
        )
      end
    end

    def table_data
      table_headers = [
        t('payment.pdf.items.header.description'),
        t('payment.pdf.items.header.period'),
        t('payment.pdf.items.header.units'),
        t('payment.pdf.items.header.unit_price'),
        t('payment.pdf.items.header.amount')
      ]
      line_items.unshift(table_headers).push(subtotal_and_tax, total)
    end

    def line_items
      subscription_items + adjustment_items
    end

    def subscription_items
      @invoice.lines.data.select { |line| line.type.eql?('subscription') }.map do |line|
        [
          t("payment.plan.#{line.plan.id}"),
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
            t('payment.pdf.items.value.adjustment',
              plan: t("payment.plan.#{set.first[0]}")),
            period(set.first[1], set.first[2]),
            nil,
            nil,
            in_chf(amount_sum)
          ]
        end.compact
    end

    def subtotal_and_tax
      headers = t('payment.pdf.items.subtotal',
        subtotal: in_chf(@invoice.subtotal),
        tva: @invoice.tax_percent.to_i)
      [nil, nil, nil, headers, "#{in_chf(@invoice.subtotal)}\n#{in_chf(@invoice.tax)}"]
    end

    def total
      [nil, nil, nil, t('payment.pdf.items.total_due'), in_chf(@invoice.amount_due)]
    end

    def period(period_start, period_end)
      t('payment.pdf.items.value.period',
        period_start: l(period_start.to_date, format: :short),
        period_end: l(period_end.to_date, format: :short))
    end

    def units(line)
      line.quantity if line.type.eql?('subscription')
    end

    def unit_price(line)
      in_chf(line.plan.amount) if line.type.eql?('subscription')
    end

    def in_chf(amount)
      amount = 0 unless amount.present?
      format('%.2f', amount / 100.00)
    end
  end
end
