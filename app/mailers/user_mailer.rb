class UserMailer < ApplicationMailer
  default from: ENV.fetch('EMAIL_FROM', 'support@mail.karya-app.com') 

  # Sends an email based on a named template.
  # Rendering precedence:
  # 1. app/views/email_templates/<template_name>.html.erb (with variables available)
  # 2. EmailTemplate#body stored in DB (interpreted as HTML)
  # Returns Mail::Message or nil if template missing.

  def send_template_email(user_email, template_name, variables = {})
    template = EmailTemplate.find_by(name: template_name)
    return unless template

    @variables = variables.with_indifferent_access
    # Allow callers to omit banner_image_url; fallback via ENV in template.
    subject_text = template.subject

    view_path = "email_templates/#{template_name}"

    if lookup_context.template_exists?(template_name, ['email_templates'], true)
      mail(to: user_email, subject: subject_text) do |format|
        format.html { render view_path }
      end
    elsif template.body.present?
      # Fallback to stored body (ERB evaluation optional—keeping simple for safety)
      body_html = template.body
      mail(to: user_email, subject: subject_text) do |format|
        format.html { render html: body_html.html_safe }
      end
    else
      nil
    end
  end
end
