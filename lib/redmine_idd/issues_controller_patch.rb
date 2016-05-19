module RedmineIdd
  module IssuesControllerPatch
    def self.included(base)
      base.class_eval do
        def build_new_issue_from_params
          @issue = Issue.new
          if params[:copy_from]
            begin
              @issue.init_journal(User.current)
              @copy_from = Issue.visible.find(params[:copy_from])
              unless User.current.allowed_to?(:copy_issues, @copy_from.project)
                raise ::Unauthorized
              end
              @link_copy = link_copy?(params[:link_copy]) || request.get?
              @copy_attachments = params[:copy_attachments].present? || request.get?
              @copy_subtasks = params[:copy_subtasks].present? || request.get?
              @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks, :link => @link_copy)
            rescue ActiveRecord::RecordNotFound
              render_404
              return
            end
          end
          @issue.project = @project
          if request.get?
            @issue.project ||= @issue.allowed_target_projects.first
          end
          @issue.author ||= User.current
          @issue.start_date ||= DateTime.now if Setting.default_issue_start_date_to_creation_date?

          attrs = (params[:issue] || {}).deep_dup
          if action_name == 'new' && params[:was_default_status] == attrs[:status_id]
            attrs.delete(:status_id)
          end
          if action_name == 'new' && params[:form_update_triggered_by] == 'issue_project_id'
            # Discard submitted version when changing the project on the issue form
            # so we can use the default version for the new project
            attrs.delete(:fixed_version_id)
          end


          @issue.safe_attributes = attrs

          if @issue.project
            @issue.tracker ||= @issue.project.trackers.first
            if @issue.tracker.nil?
              render_error l(:error_no_tracker_in_project)
              return false
            end
            if @issue.status.nil?
              render_error l(:error_no_default_issue_status)
              return false
            end
          end

          @priorities = IssuePriority.active
          @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
        end
      end
    end
  end
end