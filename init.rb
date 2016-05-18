Redmine::Plugin.register :redmine_issue_due_date do
  name 'Redmine Issue Due Date plugin'
  author 'Bilel KEDIDI'
  description 'This is a plugin for Redmine to automatically set the due date'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'


  settings({
               :partial => 'redmine_idd/settings',
               :default => {
                   'setting_done' => false,
               }
           })
end

Rails.application.config.to_prepare do
  require_dependency 'redmine_idd/hooks'
  ApplicationHelper.send(:include, RedmineIdd::ApplicationHelperPatch )
  QueriesHelper.send(:include, RedmineIdd::QueriesHelperPatch )
  Project.send(:include, RedmineIdd::ProjectPatch )
  Issue.send(:include, RedmineIdd::IssuePatch )
  Version.send(:include, RedmineIdd::VersionPatch )
  Redmine::Helpers::Calendar.send(:include, RedmineIdd::CalendarPatch )
  Redmine::Helpers::Gantt.send(:include, RedmineIdd::GanttPatch )
  Redmine::I18n.send(:include, RedmineIdd::I18nPatch )
  Redmine::Utils::DateCalculation.send(:include, RedmineIdd::DateCalculationPatch )
end
