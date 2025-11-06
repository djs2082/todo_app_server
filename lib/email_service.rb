module EmailService
  class << self
    def send_email(to:, template_name:, context: {}, **options)
      return unless to.present? && template_name.present?

      async = options.fetch(:async, true)
      from  = options[:from] || default_from_address
      subject = options[:subject]

      delivery = UserMailer.send_template_email(to, template_name, context, subject: subject, from: from)
      return unless delivery

      async ? delivery.deliver_later : delivery.deliver_now
    rescue => e
      handle_error(e, to, template_name, context)
      nil
    end

    def send_bulk_email(recipients:, template_name:, context: {}, **options)
      Array(recipients).filter_map do |recipient|
        next if recipient.blank?
        send_email(to: recipient, template_name: template_name, context: context, **options)
      end
    end

    

    
    private

    def default_from_address
      UserMailer.default[:from] || 'support@mail.karya-app.com'
    end

    def handle_error(error, to, template_name, context)
      Rails.logger.error do
        "EmailService failed to send email:\n" \
        "  To: #{to}\n" \
        "  Template: #{template_name}\n" \
        "  Context: #{context.inspect}\n" \
        "  Error: #{error.class} - #{error.message}\n" \
        "  Backtrace: #{error.backtrace&.first(3)&.join("\n    ")}"
      end
    end
  end
end