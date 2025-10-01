module EmailService
  class << self
    # Send an email using a template
    # 
    # @param to [String] recipient email address
    # @param template_name [String] name of the email template
    # @param context [Hash] variables to be passed to the template
    # @param options [Hash] optional parameters
    # @option options [String] :from override default from address
    # @option options [Boolean] :async (true) whether to deliver asynchronously
    # @option options [String] :subject override template subject
    # 
    # @return [Mail::Message, nil] the mail message or nil if template not found
    # 
    # @example
    #   EmailService.send_email(
    #     to: 'user@example.com',
    #     template_name: 'welcome',
    #     context: { first_name: 'John', activation_url: 'https://...' }
    #   )
    def send_email(to:, template_name:, context: {}, **options)
      return nil if to.blank? || template_name.blank?

      # Set defaults
      async = options.fetch(:async, true)
      from_email = options[:from] || default_from_address

      begin
        # Prepare the mail
        mail = UserMailer.send_template_email('karya.app1@gmail.com', template_name, context)
        
        return nil unless mail

        # Override subject if provided
        if options[:subject].present?
          mail.subject = options[:subject]
        end

        # Override from if provided
        if from_email != UserMailer.default[:from]
          mail.from = from_email
        end

        # Deliver the email
        if async
          mail.deliver_later
        else
          mail.deliver_now
        end

        mail
      rescue => e
        handle_error(e, to, template_name, context)
        nil
      end
    end

    # Send email synchronously (convenience method)
    def send_email_now(to:, template_name:, context: {}, **options)
      send_email(to: to, template_name: template_name, context: context, async: false, **options)
    end

    # Send email to multiple recipients
    # 
    # @param recipients [Array<String>] array of email addresses
    # @param template_name [String] name of the email template
    # @param context [Hash] variables to be passed to the template
    # @param options [Hash] optional parameters
    # 
    # @return [Array<Mail::Message>] array of sent messages (excludes failures)
    def send_bulk_email(recipients:, template_name:, context: {}, **options)
      return [] if recipients.blank?

      sent_messages = []
      
      recipients.each do |recipient|
        next if recipient.blank?
        
        mail = send_email(
          to: recipient, 
          template_name: template_name, 
          context: context, 
          **options
        )
        
        sent_messages << mail if mail
      end
      
      sent_messages
    end

    # Check if a template exists
    # 
    # @param template_name [String] name of the template to check
    # @return [Boolean] true if template exists
    def template_exists?(template_name)
      return false if template_name.blank?
      
      # Check if view file exists
      view_exists = ActionController::Base.new.lookup_context.template_exists?(
        template_name, 
        ['email_templates'], 
        true
      )
      
      # Check if database record exists
      db_template_exists = EmailTemplate.exists?(name: template_name)
      
      view_exists || db_template_exists
    end

    # Get available template names
    # 
    # @return [Array<String>] list of available template names
    def available_templates
      # Get templates from database
      db_templates = EmailTemplate.pluck(:name)
      
      # Get templates from views directory
      view_templates = []
      template_path = Rails.root.join('app', 'views', 'email_templates')
      
      if Dir.exist?(template_path)
        Dir.glob("#{template_path}/*.html.erb").each do |file|
          template_name = File.basename(file, '.html.erb')
          view_templates << template_name
        end
      end
      
      (db_templates + view_templates).uniq.sort
    end

    # Send a simple email without template (useful for system notifications)
    # 
    # @param to [String] recipient email address
    # @param subject [String] email subject
    # @param body [String] email body (HTML or plain text)
    # @param options [Hash] optional parameters
    def send_simple_email(to:, subject:, body:, **options)
      return nil if to.blank? || subject.blank? || body.blank?

      async = options.fetch(:async, true)
      from_email = options[:from] || default_from_address
      content_type = options.fetch(:content_type, 'html')

      begin
        mail = ActionMailer::Base.mail(
          to: to,
          from: from_email,
          subject: subject
        ) do |format|
          if content_type == 'html'
            format.html { render html: body.html_safe }
          else
            format.text { render plain: body }
          end
        end

        if async
          mail.deliver_later
        else
          mail.deliver_now
        end

        mail
      rescue => e
        handle_error(e, to, 'simple_email', { subject: subject, body_length: body.length })
        nil
      end
    end

    private

    def default_from_address
      UserMailer.default[:from] || 'noreply@karya-app.com'
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

      # Optionally notify error tracking service
      # Bugsnag.notify(error) if defined?(Bugsnag)
    end
  end
end