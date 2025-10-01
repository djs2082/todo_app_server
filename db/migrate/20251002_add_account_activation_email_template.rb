class AddAccountActivationEmailTemplate < ActiveRecord::Migration[7.1]
  # Lightweight model for data migration
  class EmailTemplate < ActiveRecord::Base
    self.table_name = 'email_templates'
  end

  NEW_SUBJECT = 'welcome to karya-app'.freeze
  OLD_SUBJECT = 'Activate your Karya App account'.freeze
  TEMPLATE_NAME = 'account_activation'.freeze

  def up
    template = EmailTemplate.find_or_initialize_by(name: TEMPLATE_NAME)
    # Only overwrite if new record or subject differs
    template.subject = NEW_SUBJECT
    template.body ||= <<~HTML
      <h1>Activate Your Account</h1>
      <p>If you are seeing this fallback, the HTML template file was not used.</p>
    HTML
    template.save!(validate: false)
  end

  def down
    template = EmailTemplate.find_by(name: TEMPLATE_NAME)
    return unless template

    # Revert only if the current subject matches what we set
    if template.subject == NEW_SUBJECT
      template.update_columns(subject: OLD_SUBJECT)
    end
  end
end
