class TaskIndexRepresenter
  class << self

    def render_collection(tasks)
      buckets = initialize_buckets
      Array(tasks).each do |task|
        status = task.status.to_s
        next unless Task.statuses.key?(status)
        buckets[status] << render_item(task)
      end
      buckets
    end

    private

    def initialize_buckets
      Task.statuses.keys.each_with_object({}) { |s, h| h[s] = [] }
    end

    def render_item(task)
      {
        id: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: task.status,
        due_date_time: task.due_date_time,
        pause_count: task.pause_count,
        total_working_time: task.total_working_time
      }.compact
    end
  end
end

