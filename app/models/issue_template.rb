class IssueTemplate < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Concerns::IssueTemplate::Common
  unloadable
  belongs_to :project
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  belongs_to :tracker
  before_save :check_default
  validates :project_id, presence: true
  validates :title, presence: true
  validates :tracker, presence: true
  validates_uniqueness_of :title, scope: :project_id
  acts_as_list scope: :tracker

  # author and project should be stable.
  safe_attributes 'title', 'description', 'tracker_id', 'note', 'enabled', 'issue_title', 'is_default',
                  'enabled_sharing', 'visible_children', 'position'
  attr_accessible :title, :tracker_id, :issue_title, :description, :note,
                  :is_default, :enabled, :enabled_sharing, :author, :project, :position

  scope :enabled_sharing, -> { where(enabled_sharing: true) }
  scope :is_default, -> { where(is_default: true) }
  scope :not_default, -> { where(is_default: false) }
  scope :search_by_project, lambda { |prolect_id|
    where(project_id: prolect_id)
  }

  #
  # In case set is_default and updated, others are also updated.
  #
  def check_default
    if is_default? && is_default_changed?
      IssueTemplate.search_by_project(project_id).search_by_tracker(tracker_id).update_all(is_default: false)
    end
  end

  def checklist
    #
    # TODO: Exception handling
    #
    return [] if checklist_json.blank?
    JSON.parse(checklist_json)
  end

  def template_json
    result = attributes
    result[:checklist] = checklist
    result.delete('checklist_json')
    template = {}
    template[:issue_template] = result
    template.to_json(root: true)
  end

  #
  # Class method
  #
  class << self
    def get_inherit_templates(project_ids, tracker_id)
      # keep ordering of project tree
      inherit_templates = []
      project_ids.each do |i|
        inherit_templates.concat(IssueTemplate.search_by_project(i)
                                     .search_by_tracker(tracker_id)
                                     .enabled
                                     .enabled_sharing
                                     .order_by_position)
      end
      inherit_templates
    end

    def get_templates_for_project_tracker(project_id, tracker_id = nil)
      IssueTemplate.search_by_project(project_id)
                   .search_by_tracker(tracker_id)
                   .enabled
                   .order_by_position
    end
  end
end
