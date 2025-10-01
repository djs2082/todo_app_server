class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def default_event_message(object)
    {}
  end
end
