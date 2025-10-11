class UserMailer < ApplicationMailer
  default from: ENV.fetch('EMAIL_FROM', 'support@mail.karya-app.com') 

  def send_template_email(user_email, template_name, variables = {})
    template = EmailTemplate.find_by(name: template_name)
    return unless template

    @variables = variables.with_indifferent_access

    subject_text = template.subject
    view_path = "email_templates/#{template_name}"
    if lookup_context.exists?(template_name, ['email_templates'], false, [:html])
      mail(to: user_email, subject: subject_text) do |format|
        format.html { render view_path }
      end
    elsif template.body.present?
      body_html = template.body
      mail(to: user_email, subject: subject_text) do |format|
        format.html { render html: body_html.html_safe }
      end
    else
      nil
    end
  end
end
