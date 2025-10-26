class TaskRepresentor
    class << self
        attr_reader :task
        def render(task)
          return nil unless task
          @task = task
          {
              task_details: task_details,
              pause_history: pause_history,
              time_summary: time_summary,
              statistics: statistics
            }
        end


        private

        def task_details
            {
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            started_at: task.started_at,
            last_resumed_at: task.last_resumed_at,
            created_at: task.created_at,
            updated_at: task.updated_at
            }
        end

        def pause_history
            {
            total_pauses: task.pause_count,
            pauses: pauses_detail,
            total_pause_time: total_pause_time,
            total_pause_time_formatted: format_duration(total_pause_time)
            }
        end

        def pauses_detail
            task.task_pauses.order(paused_at: :desc).map do |pause|
            {
                id: pause.id,
                pause_number: pause_number(pause),
                paused_at: pause.paused_at,
                resumed_at: pause.resumed_at,
                pause_duration: pause_duration(pause),
                pause_duration_formatted: format_duration(pause_duration(pause)),
                work_before_pause: pause.work_duration,
                work_before_pause_formatted: format_duration(pause.work_duration),
                reason: pause.reason,
                comment: pause.comment,
                progress_percentage: pause.progress_percentage,
                is_active: pause.active?
            }
            end
        end

        def time_summary
            {
            total_working_time: task.total_working_time,
            total_working_time_formatted: format_duration(task.total_working_time),
            total_pause_time: total_pause_time,
            total_pause_time_formatted: format_duration(total_pause_time),
            total_elapsed_time: total_elapsed_time,
            total_elapsed_time_formatted: format_duration(total_elapsed_time),
            productive_time_percentage: productive_time_percentage,
            current_session_duration: current_session_duration,
            current_session_duration_formatted: format_duration(current_session_duration)
            }
        end

        def statistics
            {
            pause_count: task.pause_count,
            average_pause_duration: average_pause_duration,
            average_pause_duration_formatted: format_duration(average_pause_duration),
            longest_pause: longest_pause_info,
            shortest_pause: shortest_pause_info,
            pauses_by_reason: pauses_by_reason,
            most_common_reason: most_common_reason
            }
        end

        # Helper methods

        def pause_number(pause)
            task.task_pauses.where('paused_at <= ?', pause.paused_at).count
        end

        def pause_duration(pause)
            return 0 if pause.resumed_at.nil?
            (pause.resumed_at - pause.paused_at).to_i
        end

        def total_pause_time
            @total_pause_time ||= task.task_pauses.where.not(resumed_at: nil).sum do |pause|
            (pause.resumed_at - pause.paused_at).to_i
            end
        end

        def total_elapsed_time
            return 0 unless task.started_at
            
            if task.completed?
            completed_at = task.updated_at
            (completed_at - task.started_at).to_i
            elsif task.started_at
            (Time.current - task.started_at).to_i
            else
            0
            end
        end

        def productive_time_percentage
            return 0 if total_elapsed_time.zero?
            ((task.total_working_time.to_f / total_elapsed_time) * 100).round(2)
        end

        def current_session_duration
            return 0 unless task.in_progress? && task.last_resumed_at
            (Time.current - task.last_resumed_at).to_i
        end

        def average_pause_duration
            completed_pauses = task.task_pauses.where.not(resumed_at: nil)
            return 0 if completed_pauses.empty?
            
            total_pause_time / completed_pauses.count
        end

        def longest_pause_info
            longest = task.task_pauses.where.not(resumed_at: nil).max_by { |p| pause_duration(p) }
            return nil unless longest

            {
            id: longest.id,
            duration: pause_duration(longest),
            duration_formatted: format_duration(pause_duration(longest)),
            reason: longest.reason,
            paused_at: longest.paused_at,
            resumed_at: longest.resumed_at
            }
        end

        def shortest_pause_info
            shortest = task.task_pauses.where.not(resumed_at: nil).min_by { |p| pause_duration(p) }
            return nil unless shortest

            {
            id: shortest.id,
            duration: pause_duration(shortest),
            duration_formatted: format_duration(pause_duration(shortest)),
            reason: shortest.reason,
            paused_at: shortest.paused_at,
            resumed_at: shortest.resumed_at
            }
        end

        def pauses_by_reason
            task.task_pauses.group(:reason).count
        end

        def most_common_reason
            pauses_by_reason.max_by { |_reason, count| count }&.first
        end

        def format_duration(seconds)
            return '0s' if seconds.zero?
            
            hours = seconds / 3600
            minutes = (seconds % 3600) / 60
            secs = seconds % 60

            parts = []
            parts << "#{hours}h" if hours > 0
            parts << "#{minutes}m" if minutes > 0
            parts << "#{secs}s" if secs > 0 || parts.empty?

            parts.join(' ')
        end
    end
end
