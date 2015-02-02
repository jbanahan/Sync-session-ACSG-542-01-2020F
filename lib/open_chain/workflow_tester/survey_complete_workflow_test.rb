module OpenChain; module WorkflowTester; class SurveyCompleteWorkflowTest
  def self.category; 'Survey'; end
  def self.pass? workflow_task
    payload = workflow_task.payload
    raise "SurveyCompleteTest must have survey_code payload setting." if payload['survey_code'].blank?
    raise "SurveyCompleteTest must have survey_rating payload setting." if payload['survey_rating'].blank?

    return !workflow_task.base_object.survey_responses.includes(:survey).where('survey_responses.rating = ?',payload['survey_rating']).where('surveys.system_code = ?',payload['survey_code']).empty?
  end
end; end; end;