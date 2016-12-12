FactoryGirl.define do
  factory :employee_file do
    trait :with_jpg do
      file File.open(File.join(Rails.root, "/spec/fixtures/files/test.jpg"))
    end

    trait :with_pdf do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/example.pdf'))
    end

    trait :with_doc do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/sample.doc'))
    end

    trait :with_docx do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/test.docx'))
    end
  end
end
