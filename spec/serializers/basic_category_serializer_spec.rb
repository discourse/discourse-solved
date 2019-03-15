require 'rails_helper'

describe BasicCategorySerializer do
  let(:category) { Fabricate(:category) }
  let(:guardian) { Guardian.new }

  before do
    SiteSetting.show_filter_by_solved_status = true
    category.custom_fields["enable_accepted_answers"] = true
    category.save_custom_fields
  end

  it "should include custom fields only if its preloaded" do
    json = described_class.new(category, scope: guardian, root: false).as_json
    expect(json.to_s).not_to include("custom_fields")

    category.expects(:custom_field_preloaded?).returns(true)
    json = described_class.new(category, scope: guardian, root: false).as_json
    expect(json.to_s).to include("custom_fields")
  end  
end
