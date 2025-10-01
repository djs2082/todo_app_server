class Event < ApplicationRecord
    include Events::Publisher
    belongs_to :subject, polymorphic: true
    belongs_to :initiator, polymorphic: true

    validates :kind, presence: true
    validates :subject_type, :subject_id, presence: true
    validates :message, presence: true

    before_save :truncate_long_message_fields
    after_commit :forward_event, on: :create


    EVENTS_LIST=[
    ]

    def forward_event
        publish(:event_created_event, self)
    end

    # Truncate common textual fields inside message hash to prevent oversized rows.
    def truncate_long_message_fields
        return unless message.is_a?(Hash)
        %w[title description detail error].each do |field|
            next unless message.key?(field)
            message[field] = message[field].to_s.truncate(500)
        end
    end
end