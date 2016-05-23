module RedmineIdd
  module IssuePatch
    def self.included(base)
      base.class_eval do
        attr_accessor :start_time
        attr_accessor :due_time
        before_save :add_start_and_due_time
        safe_attributes  'start_time', 'due_time'

        def safe_attributes=(attrs, user=User.current)
          return unless attrs.is_a?(Hash)

          attrs = attrs.deep_dup

          # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
          if (p = attrs.delete('project_id')) && safe_attribute?('project_id')
            if allowed_target_projects(user).where(:id => p.to_i).exists?
              self.project_id = p
            end

            if project_id_changed? && attrs['category_id'].to_s == category_id_was.to_s
              # Discard submitted category on previous project
              attrs.delete('category_id')
            end
          end

          if (t = attrs.delete('tracker_id')) && safe_attribute?('tracker_id')
            self.tracker_id = t
          end
          if project
            # Set the default tracker to accept custom field values
            # even if tracker is not specified
            self.tracker ||= project.trackers.first
          end

          statuses_allowed = new_statuses_allowed_to(user)
          if (s = attrs.delete('status_id')) && safe_attribute?('status_id')
            if statuses_allowed.collect(&:id).include?(s.to_i)
              self.status_id = s
            end
          end
          if new_record? && !statuses_allowed.include?(status)
            self.status = statuses_allowed.first || default_status
          end
          if (u = attrs.delete('assigned_to_id')) && safe_attribute?('assigned_to_id')
            if u.blank?
              self.assigned_to_id = nil
            else
              u = u.to_i
              if assignable_users.any?{|assignable_user| assignable_user.id == u}
                self.assigned_to_id = u
              end
            end
          end


          attrs = delete_unsafe_attributes(attrs, user)
          return if attrs.empty?

          if attrs['parent_issue_id'].present?
            s = attrs['parent_issue_id'].to_s
            unless (m = s.match(%r{\A#?(\d+)\z})) && (m[1] == parent_id.to_s || Issue.visible(user).exists?(m[1]))
              @invalid_parent_issue_id = attrs.delete('parent_issue_id')
            end
          end

          if attrs['custom_field_values'].present?
            editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
            attrs['custom_field_values'].select! {|k, v| editable_custom_field_ids.include?(k.to_s)}
          end

          if attrs['custom_fields'].present?
            editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
            attrs['custom_fields'].select! {|c| editable_custom_field_ids.include?(c['id'].to_s)}
          end

          # mass-assignment security bypass
          assign_attributes attrs, :without_protection => true

          # Helper to make sure that when we load in the time it takes into account that it is supplied localised and must be converted back to utc.
          def load_localised_time(date, time, time_zone)
            localised_date = {:year => date.year, :month => date.month, :day => date.day}
            localised_datetime = date.in_time_zone(time_zone).change({:hour => time['hour'].to_i, :min => time['minute'].to_i})
            return localised_datetime.change(localised_date).utc
          end

          if self.start_date.is_a?(Time) && (@start_time = {'hour'=> self.start_date.strftime('%H'), 'minute'=> self.start_date.strftime('%M')}) && safe_attribute?('start_time')
            self.start_date = load_localised_time(self.start_date, @start_time, user.time_zone)
          end

          if self.due_date.is_a?(Time) &&  (@due_time = {'hour'=> self.due_date.strftime('%H'), 'minute'=> self.due_date.strftime('%M')}) && safe_attribute?('due_time')
            self.due_date = load_localised_time(self.due_date, @due_time, user.time_zone)
          end
        end

        # Callback on start and due time
        def add_start_and_due_time
          return if not project.use_datetime_for_issues

          # Not sure if this is a hack or not, but it works :)
          time_zone = User.current.time_zone
          system_time_zone = Time.zone
          if time_zone
            Time.zone = time_zone
          end
          zone = User.current.time_zone
          if st=@start_time and sd=start_date
            if st['hour'].to_i >= 0 or st['minute'].to_i >= 0
              time = Time.parse( "#{sd.year}.#{sd.month}.#{sd.day} #{st['hour']}:#{st['minute']}:00" ) # Parse in as local but save as UTC

              self.start_date = zone ? time.in_time_zone(zone) : (time.utc? ? time.localtime : time)
            end
          end

          if dt=@due_time and dd=due_date
            if dt['hour'].to_i >= 0 or dt['minute'].to_i >= 0
              time =  Time.parse( "#{dd.year}.#{dd.month}.#{dd.day} #{dt['hour']}:#{dt['minute']}:00") # Parse in as local but save as UTC
              self.due_date = zone ? time.in_time_zone(zone) : (time.utc? ? time.localtime : time)
            end
          end

          # Since we fudged the timezone to get the values parsing in okay, let's reset it to the system timezone.
          Time.zone = system_time_zone
        end
      end
    end
  end
end