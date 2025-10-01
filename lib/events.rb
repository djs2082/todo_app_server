class Events
    cattr_accessor :queue
    self.queue = Hash.new { |hash, key| hash[key] = {} }

    class << self
        def subscribe(subscriber, event, method_name)
            queue[event][subscriber] = method_name
        end

        def publish(event, *args)
            queue[event].each do |subscriber, method_name|
                begin
                    subscriber.send(method_name, event, *args)
                rescue => e
                    Rails.logger.error("Error in event subscriber for '#{event}': #{e.message}")
                end
            end
        end
    end

    module Publisher
        def publish(event, *args)
            Events.publish(event, *args)
        end
    end

    module Subscriber
        def subscribe(event, method_name = nil)
            [*event].each { |e| Events.subscribe(self, e, method_name) }
        end
    end
end